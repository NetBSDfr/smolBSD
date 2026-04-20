# 💥 Crush service

## 📖 About

This microservice runs [crush](https://github.com/charmbracelet/crush), an AI-powered terminal assistant built by Charmbracelet. It provides a fully configured NetBSD microvm with crush pre-installed and ready to use.

The service mounts your project directory at `/mnt` inside the microvm, allowing you to work on any project with crush's AI capabilities in a lightweight, fast-booting environment.

## 🎒 Prerequisites

- A `crush.json` configuration file (see [crush docs](https://github.com/charmbracelet/crush))
- At least 512MB of memory recommended

## 🚀 Usage

### 🔨 Build the image

```sh
$ ./smoler.sh build -y dockerfiles/Dockerfile.crush
```

Or pull the pre-built image:

```sh
$ ./smoler.sh pull crush-amd64:latest
```

### ▶️ Run with a project directory

```sh
$ ./smoler.sh run crush-amd64:latest -m 1024 -w /path/to/project
```

The `-w` flag mounts `/path/to/project` at `/mnt` inside the microvm. The `-m 1024` allocates 1GB of memory.

### ⚡ Run with an inline crush config

```sh
$ ./smoler.sh run crush-amd64:latest -E crush=/path/to/crush.json
```

This passes a `crush.json` file directly into the microvm at `/var/qemufwcfg/opt/org.smolbsd.file.crush`.

### 🔧 Run with a custom config file

Copy your `crush.json` into the working directory before running:

```sh
$ cp crush.json /path/to/project/
$ ./smoler.sh run crush-amd64:latest -m 1024 -w /path/to/project
```

### 💻 Interactive shell (no crush)

If no `crush.json` is found, the microvm drops to a `ksh` prompt. You can also start it directly:

```sh
$ ./startnb.sh -f etc/crush.conf
```

## 🛑 Exiting

When shutting down the microvm, use **Ctrl-A Ctrl-X** to exit.

## ⚙️ Configuration

The service runs as user `crush` with the following environment:

- Working directory: `/home/crush`
- Shell profile launches crush automatically on login
- Tmux is configured (status bar disabled)
- File descriptor limit set to 4096
