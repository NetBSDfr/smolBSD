# 💥 Crush service

## 📖 About

This service runs [crush](https://github.com/charmbracelet/crush), an AI-powered terminal assistant built by Charmbracelet. It provides a fully configured NetBSD microvm with crush pre-installed and ready to use.

## 🎒 Prerequisites

- A `crush.json` configuration file (an example is included in this repository, or see [crush docs](https://github.com/charmbracelet/crush))
- At least 512MB of memory recommended

## 🚀 Usage

### 🔨 Build the image

```sh
$ ./smoler.sh build -y smolerfiles/Dockerfile.crush
```

Or pull the pre-built image:

```sh
$ ./smoler.sh pull crush-amd64:latest
```

### ⚡ Quick start (config via command line)

```sh
$ ./smoler.sh run crush-amd64:latest -m 1024 -E crush=/path/to/crush.json -w /path/to/project
```

Passes the config file from the host directly to the guest with `-E`, and the path for the project file you want `crush` to work on, it will be mounted in the microvm `/mnt` directory.

### 🔧 Full project (mount a directory)

Keep a `crush.json` in each project directory for a ready-to-go setup:

```sh
$ cp crush.json /path/to/project/
$ ./smoler.sh run crush-amd64:latest -m 1024 -w /path/to/project
```

### 📋 Flags

| Flag | Description |
|------|-------------|
| `-m <mb>` | Memory to allocate (default: 512) |
| `-E crush=<path>` | Pass a config file directly to the guest |
| `-w <path>` | Mount a directory at `/mnt` inside the microvm |

### ⚠️ No config found

If no `crush.json` is available, crush won't start and the microvm drops to a `ksh` prompt instead.

## 🛑 Exiting

When shutting down the microvm, use **Ctrl-A Ctrl-X** to exit.

## ⚙️ Configuration

The service runs as user `crush` with the following environment:

- Working directory: `/home/crush`
- Shell profile launches crush automatically on login
- Tmux is configured (status bar disabled)
- File descriptor limit set to 4096
