<div align="center" markdown="1">

<img src="images/smolClaw.png" width=500px>

# smolClaw

<img src="images/smolcap.png" width=500px>

[picoclaw][1] running on a microVM!

</div>

**smolClaw** is a [smolBSD][2] microVM appliance that runs
[picoclaw][1] on Linux or macOS.

Running picoclaw inside a microVM provides:

* Minimal footprint
* Strong isolation of memory and filesystem
* Fast startup (under one second)

As per the [smolBSD][2] design, the VM boots directly into a `tmux`
console with default bindings running `bash`.

# Quickstart

* Fetch [smolBSD][2] and install dependencies

```sh
git clone https://github.com/NetBSDfr/smolBSD
```
Debian, Ubuntu and the like
```sh
sudo apt install curl git bmake qemu-system-x86_64 binutils uuid-runtime libarchive-tools gdisk socat jq lsof picocom
```
macOS
```sh
brew install curl git bmake qemu binutils libarchive socat jq lsof picocom
```

* Go to the `smolBSD` directory and
```sh
cd smolBSD
```
  * Pull the ghcr.io _smolClaw_ image (`amd64` and `evbarm-aarch64` images available)
```sh
./smoler.sh pull clawd-amd64:latest
```
  * OR build it yourself
```sh
./smoler.sh build -y smolerfiles/Dockerfile.clawd
```

* Run the microVM

```sh
./smoler.sh run clawd-amd64:latest -c 2 -m 1024
```

Options:

- `-c` → CPU cores
- `-m` → RAM in MB

To share a host directory:

```sh
./smoler.sh run clawd-amd64:latest -c 2 -m 1024 -w /path/to/directory
```

Inside the VM it will be mounted at:

```
/mnt
```

* Once the microVM has started, begin onboarding

```sh
[~]@😈+🦞> picoclaw onboard
```

* When the configuration is finished, start the gateway

```sh
[~]@😈+🦞> picoclaw gateway
```

[picoclaw][1] Quickstart is available [here](https://github.com/sipeed/picoclaw/?tab=readme-ov-file#-quick-start)

## SSH access

* You can build _smolClaw_ with your _SSH_ public key just by copying it to `share/ssh.pub`
* You can also do it once the microvm is started but you'll have to re-do it at every build:
```sh
[~]@😈+🦞> mkdir -p ~/.ssh && cat >~/.ssh/authorized_keys
```
Just paste your public key and press Ctrl+D, then
```sh
[~]@😈+🦞> chmod 600 ~/.ssh/authorized_keys
```

In both cases, you'll be able to _SSH_ to your _smolClaw_ instance like this:

```sh
$ ssh -p 2289 clawd@localhost
```

---

### Troubleshooting "Could not access KVM kernel module: No such file or directory"
The error says KVM (hardware virtualization) isn't available. This usually means either:

1. KVM module isn't loaded:
```sh
sudo modprobe kvm kvm_intel   # for Intel CPUs
# or
sudo modprobe kvm kvm_amd     # for AMD CPUs
```
Then check it's there:
```sh
ls /dev/kvm
```

2. Virtualization is disabled in your BIOS/UEFI
If modprobe fails, reboot into BIOS and enable "Intel VT-x" or "AMD-V" (sometimes called "SVM Mode"). It's usually under CPU settings or Advanced.

You can check if your CPU supports it at all with:
```sh
grep -Ec '(vmx|svm)' /proc/cpuinfo
```
If that returns 0, either it's disabled in BIOS or your CPU doesn't support it.

3. Are you inside a VM already?
If you're running Ubuntu inside a VM (like VirtualBox or VMware), you need to enable nested virtualization in the hypervisor's settings. For VirtualBox that's "Enable Nested VT-x/AMD-V" in the VM's system settings.


[1]: https://github.com/sipeed/picoclaw
[2]: https://smolBSD.org
