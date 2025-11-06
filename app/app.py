import json
import logging
import os
import psutil
import socket
import subprocess
import dotenv
import sys
from flask import Flask, send_file, jsonify, request

app = Flask(__name__)
# Get environment variables from .flaskenv / .env
dotenv.load_dotenv()

cwd = os.environ['FLASK_CWD'] if 'FLASK_CWD' in os.environ else '..'
loglevel = int(os.environ['FLASK_LOGLEVEL']) if 'FLASK_LOGLEVEL' in os.environ else logging.ERROR
log = logging.getLogger('werkzeug')
log.setLevel(loglevel)

vmlist = {}

def get_vmlist():
    vmlist.clear()
    for filename in os.listdir(f'{cwd}/etc'):
        if filename.endswith('.conf'):
            vmname = filename.split(".conf")[0]
            config_data = {}
            with open(f'{cwd}/etc/{filename}', 'r') as f:
                lines = f.readlines()
                for line in lines:
                    line = line.strip()
                    if not line:
                        continue
                    elif line.startswith('#') or line.startswith('extra'):
                        continue
                    elif '=' in line:
                        key, value = line.split('=', 1)
                        config_data[key.strip()] = value.strip()

            # Check if QEMU process is running
            status = 'running' if get_pid(vmname) > 0 else 'stopped'

            vmlist[vmname] = config_data
            vmlist[vmname]['status'] = status

    return vmlist


def list_files(path):
    try:
        items = os.listdir(path)
        return jsonify(items)
    except FileNotFoundError:
        return jsonify({"error": "Directory not found"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500


def get_port(vmname, service, default_port):
    port = default_port
    if vmname in vmlist and service in vmlist[vmname]:
        return vmlist[vmname][service]
    for vm in vmlist:
        if not service in vmlist[vm]:
            continue
        vm_port = int(vmlist[vm][service])
        if vm_port >= port:
            port = vm_port + 1

    return port


def query_qmp(command, vmname):
    if not 'qmp_port' in vmlist[vmname]:
        return jsonify(
            {"success": False, "message": f"QMP not enabled in {vmname}"}
        ), 404

    qmp_port = int(vmlist[vmname]['qmp_port'])

    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        rep_len = 8192
        s.connect(("localhost", qmp_port))
        response = s.recv(rep_len)
        # mandatory before command (duh?)
        s.sendall('{"execute": "qmp_capabilities"}\n'.encode('utf-8'))
        response = s.recv(rep_len)
        # actual command
        s.sendall(f'{{"execute": "{command}"}}\n'.encode('utf-8'))
        response = s.recv(rep_len)

        return json.loads(response)

def get_pid(vmname):
    pid_file = f"{cwd}/qemu-{vmname}.pid"
    if not os.path.exists(pid_file):
        return -1
    f = open(pid_file, "r")
    pid = int(f.read().strip())
    if psutil.pid_exists(pid):
        return pid
    else:
        return -1

def get_cpu_usage(vmname):
    ncpus = 1
    r = query_qmp("query-cpus-fast", vmname)
    if r and 'return' in r:
        ncpus = len(r['return'])
    pid = get_pid(vmname)
    if pid < 0:
        return 0
    process = psutil.Process(pid)
    return process.cpu_percent(interval=0.1) / ncpus

## routes

@app.route("/")
def index():
    # do not render template, frontend logic handled by Vue
    return send_file("index.html")

@app.route("/static/smolBSD.png")
def assets():
    return send_file("static/smolBSD.png")

@app.route("/vmlist")
def vm_list():
    return jsonify(get_vmlist())


@app.route("/getkernels")
def getkernels():
    return list_files(f'{cwd}/kernels/')


@app.route("/getimages")
def getimages():
    return list_files(f'{cwd}/images/')


@app.route("/start", methods=["POST"])
def start_vm():
    vm_name = request.json.get("vm_name")

    config_file = f'{cwd}/etc/{vm_name}.conf'

    if not os.path.exists(config_file):
        return jsonify(
            {"success": False, "message": "Config file not found"}
        ), 404

    try:
        ret = subprocess.Popen([f"{cwd}/startnb.sh", "-f", config_file, "-d"], cwd=cwd)
        return jsonify({"success": True, "message": "Starting VM"})
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@app.route("/stop", methods=["POST"])
def stop_vm():
    vm_name = request.json.get("vm_name")
    pid_file = f'{cwd}/qemu-{vm_name}.pid'

    try:
        pid = get_pid(vm_name)
        if pid < 0:
            return jsonify(
                {"success": False, "message": "PID file not found"}
            ), 404
        os.kill(int(pid), 15)
        os.remove(pid_file)
        return jsonify({"success": True, "message": "Stopping VM"})
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@app.route("/saveconf", methods=['POST'])
def saveconf():
    try:
        data = request.get_json()
        if not data:
            return jsonify(
                {"success": False, "message": "No JSON payload provided"}
            ), 400

        vmname = data.get("vm")
        if not vmname:
            return jsonify(
                {
                    "success": False,
                    "message": "'vm' key is required in the JSON payload"
                }
            ), 400

        os.makedirs(f'{cwd}/etc', exist_ok=True)
        file_path = f"{cwd}/etc/{vmname}.conf"

        with open(file_path, 'w') as file:
            for key, value in data.items():
                if key == "tcpserial":
                    if value is True:
                        serial_port = get_port(vmname, 'serial_port', 5555)
                        key = "serial_port"
                        value = f"{serial_port}"
                    else:
                        continue
                if key == "rmprotect" and value == False:
                    continue

                file.write(f"{key}={value}\n")

            qmp_port = get_port(vmname, 'qmp_port', 4444)
            file.write(f'qmp_port={qmp_port}\n')
            extra = 'extra="-pidfile qemu-${vm}.pid"'
            file.write(f'{extra}\n')

        return jsonify({"success": True, "message": file_path}), 200

    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@app.route('/rm/<vm>', methods=['DELETE'])
def rm_file(vm):
    try:
        filepath = f"{cwd}/etc/{vm}.conf"

        if not os.path.isfile(filepath):
            return jsonify(
                {"success": False, "message": f"'{vm}' not found"}
            ), 404

        os.remove(filepath)
        return jsonify(
            {"success": True, "message": f"'{vm}' deleted successfully"}
        ), 200

    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@app.route('/qmp/<vmname>/<command>')
def qmp(vmname, command):
    try:
        response = query_qmp(command, vmname)
        return response
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@app.route('/cpu_usage/<vmname>')
def cpu_usage(vmname):
    try:
        return f"{get_cpu_usage(vmname)}\n"
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500

if __name__ in ["__main__", "app"]:
    vmlist = get_vmlist()
    if __name__ == "__main__":
        app.run()
