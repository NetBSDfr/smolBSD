# 🧊 Quaude service

## About

This service runs [quaude](https://github.com/schmonz/clode), Claude Code repackaged for machines upstream doesn't ship for: `clode` extracts the JavaScript from the upstream `claude` Bun binary, rebases the Bun calls onto Node equivalents and compiles everything to QuickJS-NG (txiki.js) bytecode. The result is a self-contained binary — no Node, no npm at run time.

`clode` is the builder and ships as a NetBSD binary; `quaude` carries Anthropic's code, is a derived work and is never distributed. So the image ships `clode` plus quaude's runtime tools (`bash`, `bfs`, `ugrep`) and you build quaude once yourself, on first boot:

```
clode fetch claude && clode build
```

quaude runs inside `tmux` under a PTY console, like the other agent images.

## Prerequisites

- [smolBSD](https://github.com/NetBSDfr/smolBSD): `git clone https://github.com/NetBSDfr/smolBSD`
- Network access on first boot (the `claude` release is fetched and sha256-verified by `clode fetch`)
- An `ANTHROPIC_API_KEY`, or an Anthropic account for the OAuth login flow

## Usage

### 🔨 Build the image

```sh
$ ./smoler.sh build -y smolerfiles/SMOLerfile.quaude
```

Pin a specific clode version if needed:

```sh
$ ./smoler.sh build -y --build-arg CLODE_VERSION=0.20260831.1 smolerfiles/SMOLerfile.quaude
```

**Or** pull the pre-built image (built by CI for both architectures):

Linux:
```sh
$ ./smoler.sh pull quaude-amd64:latest
```

Mac or any `arm64` machine:
```sh
$ ./smoler.sh pull quaude-evbarm-aarch64:latest
```

### ⚡ Quick start

Linux:
```sh
$ ./smoler.sh run quaude-amd64:latest -m 1024 -E ANTHROPIC_API_KEY=sk-ant-...
```

Mac or any `arm64` machine:
```sh
$ ./smoler.sh run quaude-evbarm-aarch64:latest -m 1024 -E ANTHROPIC_API_KEY=sk-ant-...
```

On first boot there is no `./quaude` yet, so the VM drops to a `ksh` shell with the build hint. Run:

```
clode fetch claude && clode build
```

then `./cmd.sh` to start the session. The build only needs to be redone to update Claude Code (or when `clode` itself is updated).

### 📋 Flags

| Flag | Description |
|------|-------------|
| `-m <mb>` | Memory to allocate (default: 512) |
| `-E ANTHROPIC_API_KEY=sk-ant-...` | API key, exported before quaude starts |
| `-E claudeconf=<path>` | Pass a Claude Code `settings.json` directly |
| `-w <path>` | Mount a directory at `/mnt` inside the microvm |

There are two ways to get a `settings.json` into the VM:

1. Drop a `settings.json` in the shared directory (copied from `/mnt/settings.json`)
2. Pass it from the host with `-E claudeconf=/path/to/settings.json` (delivered via QEMU fw_cfg)

Without a key, quaude starts Claude Code's interactive OAuth login instead.

### ⚙️ Persisting state

`./quaude`, `.claude/` (login, settings, history) and `.claude.json` live in the image and are lost on reboot. To keep them, share a host directory with `-w /path/to/directory` and put the state under `share/quaude/`: its contents are copied into `.claude/` at every boot (one-way, copy it back yourself to refresh the host copy).

### ⌨️ Session flow

Once `./quaude` exists, the console shows:

```
🧊 quaude runs inside tmux with prefix ^b

⌨️  Press enter to start the session
```

Press **enter**: quaude starts in a new tmux session (prefix `^b`, vi mode keys, bash as default shell).

## Exiting

When shutting down the microvm, use **Ctrl-A Ctrl-X** to exit.
