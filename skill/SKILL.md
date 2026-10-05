---
name: smolbsd
description: >
  Complete smolBSD platform expertise — the entire framework for building minimal NetBSD microVMs.
  Covers full lifecycle: SMOLerfile (Dockerfile-compatible) authoring, manual service directory creation,
  the dual build system (smoler.sh high-level vs bmake low-level), mkimg.sh image creation internals,
  startnb.sh QEMU/Firecracker PVH boot (~10ms), OCI registry push/pull (oras), networking & port publishing,
  bidirectional VirtIO sockets, BIOS/baremetal boot with confkerndev kernel slimming,
  GitHub Actions CI/CD pipeline, and every option, script, and convention.
  Includes a debugging playbook for known sharp edges (WAPBL vs. minimize/sailor, fstab corruption,
  PAM/utmpx failures in stripped images) and POSIX shell portability conventions.
  Supports amd64, i386, evbarm-aarch64.
compatibility:
  - qemu-system-x86_64 / qemu-system-i386 / qemu-system-aarch64
  - bmake (host only — NetBSD: make; Linux/macOS: bmake)
  - make (inside builder VM — NetBSD native)
  - tar / bsdtar
  - curl
  - jq
  - POSIX sh or ksh (NOT bash — see §21)
  - sudo / doas
  - uuidgen
  - nm
  - sgdisk (Linux only)
  - lsof
  - socat (optional)
  - oras (OCI push/pull)
  - docker (optional, for Dockerfile reference)
  - git
  - rsync
metadata:
  version: "3.2"
  author: iMil / smolBSD community (document maintained by Qwen 3.8 27B)
  last-updated: "2026-09-04"
  changelog: >
    3.2 — Full verification pass against the codebase. Fixed: startnb.sh -P
    default console is picocom (not cu(1)); RTC is always
    base=utc,clock=host,driftfix=slew (not localtime); aarch64 kernel is
    netbsd-SMOL-aarch64.img (not GENERIC64) and machine flags are
    -M virt,gic-version=host|3; FreeBSD is a supported native build host
    (gpart/mdconfig/newfs), macOS is rejected by mkimg.sh; missing -l
    (comma-separated multiple drives) and -r flags documented; mkimg.sh
    step order corrected (fstab written right after set extraction);
    smolsig/OCI pull semantics and images column layout corrected; second
    CI workflow (smoler.yml) documented; sailor invocation details and
    current WAPBL guard documented.
    3.1 — Added §20 debugging playbook for real sailor/WAPBL, fstab-NUL, and
    login/PAM/utmpx failures encountered during ARM64 and image-minimization work;
    added §21 shell/portability conventions; documented service/common/sailor.vars;
    clarified the images subcommand's proportional-column output and the -P pty flag
    in startnb.sh; corrected the minimize/resize ordering caveat in §13.
---

# smolBSD — Complete Platform Reference

This skill provides exhaustive knowledge of the entire smolBSD framework — enough for an agent to understand, navigate, extend, and debug every aspect of the project.

**Read §20 (Debugging Playbook) before touching anything related to image minimization, sailor, or login/PAM in a stripped image** — these are the areas that have produced the most subtle real-world failures and are easy to misdiagnose from source alone.

## 1. Project Overview

**smolBSD** builds minimal, fast-booting NetBSD virtual machines (microVMs). Key properties:

- **~10 ms boot** via PVH (PVHv2) on QEMU `microvm` machine type
- **No prior NetBSD installation** required on the host
- **Immutable by design** — images are built once, booted many times
- **Host platforms**: GNU/Linux, NetBSD, macOS (x86 VT-capable or ARM64 CPU recommended)
- **Guest architectures**: `amd64`, `i386`, `evbarm-aarch64`
- **VMMs**: QEMU (primary), Firecracker, Bhyve (BIOS mode)
- **Images** are raw `.img` disk files with FFS (NetBSD) or ext2 (Linux build hosts)

The fundamental unit is a **service** — a directory containing:
- NetBSD set selection (`base`, `etc`, `comp`, `man`, `rescue`, …)
- Build-time scripts (`postinst/*.sh`)
- Runtime init script (`etc/rc`)
- Build configuration (`options.mk`)

---

## 2. Project Directory Layout

```
smolBSD/
├── Makefile              # Entry point for manual image building (bmake)
├── mkimg.sh              # Image creation script (called by Makefile, or directly via `bmake SERVICE=<name> base`)
├── startnb.sh            # Low-level QEMU VM launcher
├── smoler.sh             # High-level CLI dispatcher: build|run|push|pull|images
├── batch.sh              # Batch launcher: N copies of a service on shifted ports
├── smoler/
│   ├── build.sh          # SMOLerfile parser → generates service dir + calls bmake
│   └── img.sh            # OCI push/pull/list (oras wrapper)
├── scripts/
│   ├── app-run.sh        # Launcher helper for the app/ GUI
│   ├── fetch.sh          # Smart curl wrapper (globbing, fresh checks)
│   ├── freshchk.sh       # Freshness check (remote Last-Modified cache in db/)
│   ├── sh                # Static shell used as /rescue/sh in rescue images
│   └── uname.sh          # Architecture/machine detection helper
├── sailor/               # Cloned sailor repo (minimization), invoked by mkimg.sh
├── service/              # All service definitions
│   ├── common/           # Shared runtime scripts bundled into /etc/include/ in VM
│   │   ├── basicrc       # Standard env, networking, devices, SSL_CERT_FILE, rc.pre/rc.local
│   │   ├── choupi        # Emoji/ASCII toggle for terminal output
│   │   ├── funcs         # rsynclite() helper (tar-based directory sync)
│   │   ├── vars          # BASEPATH, DRIVE2 path constants
│   │   ├── shutdown      # Clean halt (sync, umount, optional viocon kill signal)
│   │   ├── mount9p       # 9P filesystem mount (host directory sharing)
│   │   ├── qemufwcfg     # QEMU fw_cfg variable loader
│   │   ├── pkgin         # Package manager bootstrapper
│   │   └── sailor.vars   # Sailor integration variables
│   ├── base/             # Full base+etc system with ksh (builder image base)
│   ├── build/            # Builder microVM service (orchestrates service builds)
│   ├── rescue/           # ~10 MB minimal rescue shell
│   └── <service>/        # One directory per service
│       ├── etc/rc        # Runtime init script (MANDATORY for init(8) services)
│       ├── postinst/     # Build-time scripts executed on host/VM builder
│       ├── options.mk    # Service build variables (IMGSIZE, ADDPKGS, SETS, etc.)
│       ├── own.mk        # User overrides (git-ignored, not committed)
│       ├── sailor.conf   # Sailor minimization rules
│       ├── packages/     # Pre-built binary packages for offline install
│       └── NETBSD_ONLY   # Marker: build only on native NetBSD
├── smolerfiles/          # SMOLerfile / Dockerfile examples
│   ├── Dockerfile.inc    # Shared INCLUDE snippets
│   ├── Dockerfile.<name> # Per-service SMOLerfile (Dockerfile-compatible)
│   ├── SMOLerfile.<name> # Named SMOLerfiles (same syntax, different naming)
│   ├── *.smol            # Minimal SMOLerfiles (service name from filename)
│   └── *.inc             # Shared include fragments
├── etc/                  # VM config files for startnb.sh (-f flag)
│   └── <service>.conf    # hostfwd, imgtag, use_pty, KERNEL, NBIMG, etc.
├── bios/                 # BIOS firmware files for microvm machine type
├── confkerndev/          # Kernel driver disabler tool (SMOLIFY)
├── app/                  # Flask-based web GUI for VM management
├── www/                  # Project website and assets
├── k8s/                  # Kubernetes device plugin / deployment examples
├── misc/                 # Miscellaneous documentation
├── contribs/             # Contributed scripts
├── share/                # Shared assets (e.g. ssh.pub keys)
├── .github/workflows/    # CI/CD pipeline
│   ├── main.yml          # Builder + rescue images for amd64 + evbarm-aarch64 on push
│   └── smoler.yml        # SMOLerfile service images on smolerfiles/* push
├── db/                   # Fetch freshness cache (remote Last-Modified, see freshchk.sh)
├── images/               # Built .img disk images (empty in repo, populated at build)
├── kernels/              # Downloaded kernels (empty in repo, populated at build)
├── sets/                 # Downloaded NetBSD sets (empty in repo, populated at build)
├── pkgs/                 # Optional pre-fetched packages (empty in repo, populated at build)
├── mnt/                  # Build-time mount point (empty directory)
└── disks/                # Additional disk images
```

---

## 3. Two Workflows

### 3.1 smoler.sh (Docker-style, high-level)

`smoler.sh` is a thin dispatcher that routes subcommands to dedicated scripts:

| Command | Routes To | Purpose |
|---------|-----------|---------|
| `./smoler.sh build [-y] [-t tag] [--build-arg K=V] [VAR=val] <SMOLerfile>` | `smoler/build.sh` | Parse SMOLerfile → generate service dir → call `bmake build` |
| `./smoler.sh run <image> [startnb.sh flags]` | `startnb.sh` | Run a built image (resolves name → config file or raw path). **Any** `startnb.sh` flag passes through after the image name (e.g. `-l drive2,drive3` for extra drives, `-r`, `-e`). |
| `./smoler.sh push <image>` | `smoler/img.sh` | Push to OCI registry via oras |
| `./smoler.sh pull <image>` | `smoler/img.sh` | Pull from OCI registry via oras |
| `./smoler.sh images [ok]` | `smoler/img.sh` | List local images with size, date, signature status. Columns are sized as fixed proportions of terminal width (name = 50%, size/date/sig = 25% each); not auto-fit to content. Pass `ok` to show only images with verified `smolsig`. |

**`smoler.sh run` name resolution:**
1. Strips `-amd64:…` or `-evbarm-aarch64:…` suffix to get base service name
   (note: an `-i386:…` suffix is **not** stripped — the `etc/<base>.conf`
   lookup for i386 images is a known quirk; the `images/<image>.img`
   fallback still works with the full name)
2. Checks for `etc/<base>.conf` → passes `-f etc/<base>.conf` to `startnb.sh`
3. Falls back to checking `images/<image>.img` → passes `-i <image>` to `startnb.sh`
4. If neither exists, shows `startnb.sh -h` usage

**`smoler.sh build` regeneration:** if `service/<name>/` already exists,
build.sh deletes its `etc/rc`, `options.mk`, `postinst/` and
`etc/<name>.conf` before regenerating them. Untracked files in the service
dir (e.g. `sailor.conf`, `own.mk`) survive, but anything hand-edited in the
deleted files is lost — commit what matters first.

### 3.2 bmake / make (Manual, low-level)

| Command | Purpose |
|---------|---------|
| `bmake buildimg` | Build the builder image (native on NetBSD/FreeBSD/Linux; on macOS this fails — the `build` target falls back to `fetchimg` there) |
| `bmake fetchimg` | Download pre-built builder image from GitHub Releases (macOS, no FFS support) |
| `bmake SERVICE=<name> build` | Build a service image using the builder microVM |
| `bmake SERVICE=<name> base` | Build only the base filesystem (no builder VM — runs `mkimg.sh` directly) |
| `bmake SERVICE=<name> MOUNTRO=y build` | Build with read-only root |
| `bmake SERVICE=<name> ARCH=evbarm-aarch64 build` | Build for ARM64 |
| `bmake kernfetch` | Download the appropriate kernel |
| `bmake setfetch` | Download NetBSD sets |
| `bmake pkgfetch` | Download binary packages |
| `bmake fetchall` | All of the above |
| `bmake rescue` | Shortcut: `SERVICE=rescue build` |
| `bmake live` | Fetch a full NetBSD live image |

**Platform-specific builder image behavior (Makefile `build` target):**
- On **NetBSD/FreeBSD/Linux**: builds the builder image natively (`bmake buildimg`)
- On **macOS** (and any other OS): fetches the pre-built builder image from GitHub (`bmake fetchimg`); running `buildimg` directly on macOS fails because mkimg.sh rejects macOS
- Builder image freshness is checked via SHA256; rebuilds/fetches only when the remote changes

---

## 4. SMOLerfile / Dockerfile Reference

SMOLerfiles are nearly 100% Dockerfile-compatible. `smoler/build.sh` parses them line-by-line and generates:
- `service/<name>/options.mk` — build variables
- `service/<name>/etc/rc` — runtime init script
- `service/<name>/postinst/postinst-N.sh` — build-time execution scripts
- `etc/<name>.conf` — VM config for `startnb.sh`

### 4.1 Parsing Flow (build.sh internals)

1. **INCLUDE expansion**: `INCLUDE <file>` directives are resolved first by catting the referenced file inline, producing a flat temporary SMOLerfile
2. **LABEL extraction**: All `LABEL` lines (with or without `smolbsd.` prefix) are extracted via `sed`/`awk`, uppercased, and written to `options.mk`
3. **Service name**: From `LABEL smolbsd.service=NAME`, or from `.smol` filename (`SMOLerfile.foo` → `SERVICE=foo`)
4. **Postinst-0.sh**: Generated with chroot setup (pkgin bootstrap, resolv.conf, openssl certs)
5. **Line-by-line parsing**: Each directive generates shell commands appended to postinst scripts or `etc/rc`
6. **Finalization**: `etc/rc` gets `. /etc/include/shutdown` appended; `etc/<name>.conf` gets `imgtag` and `use_pty`
7. **Build**: Calls `make` (NetBSD) or `bmake` (elsewhere) with `SERVICE=<name> IMGTAG=:<tag> build`

### 4.2 All Supported Directives

| Directive | Syntax | Description |
|-----------|--------|-------------|
| `FROM` | `FROM base,etc` or `FROM base-amd64.img` | Set names or an existing image name. If omitted, the Makefile `SETS` default (`base,etc`) is used. |
| `LABEL smolbsd.service=NAME` | `LABEL smolbsd.service=caddy` | **Mandatory.** Sets the service name. |
| `LABEL smolbsd.imgsize=N` | `LABEL smolbsd.imgsize=2048` | Image size in MB (default: 512). |
| `LABEL smolbsd.minimize=y` | `LABEL smolbsd.minimize=y` | Shrink to actual usage + 10%. `MINIMIZE=+N` adds N MB instead. See §13 and §20.1 before combining with WAPBL. |
| `LABEL smolbsd.publish="H:G"` | `LABEL smolbsd.publish="8881:8880,2289:22"` | Port mappings (host:guest), comma-separated. |
| `LABEL smolbsd.use_pty=y` | `LABEL smolbsd.use_pty=y` | Use PTY console (needed for interactive apps like vim/tmux). |
| `LABEL smolbsd.addpkgs="pkg1 pkg2"` | `LABEL smolbsd.addpkgs="pkgin curl"` | Packages to fetch/untar at build time (no pkgin needed). |
| `RUN` | `RUN pkgin up && pkgin -y in caddy` | Execute commands during build (chrooted). Supports heredocs (`<<EOF`). |
| `ARG` | `ARG FOO=bar` | Build argument with optional default. Override with `--build-arg FOO=val`. |
| `ENV` | `ENV NBUSER=clawd` | Set environment variable (available in build scripts and `/etc/rc`). |
| `EXPOSE` | `EXPOSE 8880` | Document exposed ports. Requires `smolbsd.publish` LABEL for actual mapping — or use the non-Docker shorthand `EXPOSE 8881:8880` (host:guest) which maps ports directly. |
| `USER` | `USER clawd` | Switch user for subsequent `RUN`, `CMD`, and `COPY` ownership. |
| `WORKDIR` | `WORKDIR /home/clawd` | Set working directory. Adds `cd` to `/etc/rc` **and** becomes the cwd for all **subsequent** `RUN` commands (including after `SHELL` switches). |
| `CMD` | `CMD caddy respond -l :8880` | Default command to run at boot (appended to `/etc/rc`). |
| `ENTRYPOINT` | (same syntax as CMD) | Treated identically to `CMD` in smolBSD. |
| `COPY` | `COPY src dest` | Copy files from build context into image. Supports `--chown`, `--chmod`, `--exclude`. |
| `ADD` | `ADD url dest` | Like `COPY` but also supports HTTP(S) URLs (fetched via `ftp`). |
| `VOLUME` | `VOLUME /data` | Declare a host directory mount point. Writes `share=` to config. |
| `SHELL` | `SHELL ["/bin/bash", "-c"]` | Change the shell used for `RUN` instructions. The `-c` flag is stripped. Creates a new postinst script. |
| `INCLUDE` | `INCLUDE Dockerfile.inc` | **smolBSD extension.** Inline the contents of another file. |

### 4.3 FROM — Set Selection Details

```dockerfile
FROM base,etc                    # Standard: base system + /etc config files
FROM base,etc,man,comp           # Full: adds man pages and compiler toolchain
FROM comp:/usr/bin/strip         # Partial: only extract /usr/bin/strip from comp set
FROM comp:/usr/libexec/*         # Glob: extract matching files from comp set
FROM base-amd64.img              # Inherit from a pre-built image
```

Valid set names: `base`, `etc`, `man`, `comp`, `rescue`, `games`, `modules`, `tests`, `text`, `xbase`, `xcomp`, `xetc`, `xfont`, `xserver`.

### 4.4 RUN — Heredoc Support

```dockerfile
RUN <<EOF
hostname myhost
ulimit -n 4096
echo 'eval \$(resize)' >> /etc/rc.local
EOF
```

The parser detects `<<EOF` (or any tag) and appends lines until the closing tag. Quotes around the tag are stripped. Heredoc content is escaped (`"` → `\"`) before being wrapped in `chroot . su ${USER} -c "..."`.

### 4.5 COPY / ADD — Options

```dockerfile
COPY --chown=clawd --chmod=600 /host/ssh.pub /home/clawd/.ssh/authorized_keys
ADD --exclude=.git ./src /app
```

- `--chown=user:group` or `--chown=user` — set ownership via `chown -R` in chroot
- `--chmod=mode` — set permissions via `chmod -R` in chroot
- `--exclude=pattern` — passed to `rsynclite` (tar-based sync)
- HTTP(S) URLs in `ADD`/`COPY` are fetched via `ftp -o`
- Destination paths starting with `$` are treated as variable references

### 4.6 Generated etc/<service>.conf Format

```sh
hostfwd=::8881-:8880,::2289-:22
imgtag=latest
use_pty=y
share=/host/path      # from VOLUME
```

### 4.7 Postinst Script Numbering

The parser generates numbered postinst scripts:
- `postinst-0.sh` — chroot bootstrap (pkgin setup, resolv.conf, openssl certs)
- `postinst-1.sh` — first RUN/COPY/ADD/USER/VOLUME/WORKDIR block (default shell)
- `postinst-N.sh` — new script created when `SHELL` directive changes the shell
- `postinst.args` — accumulated ARG/ENV exports shared across scripts

### 4.8 File Naming Conventions

- **`Dockerfile.<name>`** — standard Dockerfile naming; service name from `LABEL smolbsd.service`
- **`SMOLerfile.<name>`** — same syntax; service name from `LABEL smolbsd.service`
- **`<name>.smol`** — minimal files; service name extracted from filename itself
- **`*.inc`** — include fragments (used with `INCLUDE` directive)

### 4.9 make vs bmake

`bmake` is the **host-side** build tool (required on Linux/macOS; on NetBSD it's synonymous with `make`). It invokes the top-level `Makefile` targets (`build`, `buildimg`, `base`, …).

Inside the **builder VM** (i.e., in `RUN` directives and `postinst/*.sh` scripts), the environment is NetBSD — use plain `make`, not `bmake`. The builder VM includes `make` from the `comp` set; `bmake` is not guaranteed to be available.

```dockerfile
# Wrong (bmake is a host tool, not inside the VM):
RUN cd /tmp/src && bmake && bmake install

# Correct (plain make inside the NetBSD builder VM):
RUN cd /tmp/src && make && make install
```

---

## 5. Service Directory Manual Reference

### 5.1 options.mk — All Known Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `SERVICE` | string | (target name) | Service name, determines output filename |
| `IMGSIZE` | int | 512 | Image size in megabytes |
| `SETS` | string | `base.${SETSEXT} etc.${SETSEXT}` | NetBSD sets to include (space-separated) |
| `ADDSETS` | string | (empty) | Additional sets beyond SETS |
| `ADDPKGS` | string | (empty) | Packages to fetch and extract into image |
| `MINIMIZE` | y/+N | (empty) | `y` = +10%, `+512` = explicit MB to add |
| `MOUNTRO` | y | (empty) | Mount root read-only (`-o` passed to mkimg.sh) |
| `BIOSBOOT` | y | (empty) | Enable BIOS boot (GPT + bootxx_ffsv1) |
| `BIOSCONSOLE` | string | `com0` | Console device for BIOS boot (`com0`, `pc`) |
| `SMOLIFY` | y | (empty) | Run confkerndev to disable unused kernel drivers |
| `FROMIMG` | string | (empty) | Inherit from existing image instead of sets |
| `PKGVERS` | string | `11.0` | Package version for pkgsrc URL |
| `ARCH` | string | (detected) | Target architecture: `amd64`, `i386`, `evbarm-aarch64` |
| `CURLSH` | string | (empty) | URL to a shell script executed as finalizer |
| `SETSEXT` | string | `tar.xz` | Set archive extension (`tgz` for i386) |
| `IMGTAG` | string | (empty) | Suffix appended to image name (e.g. `:latest`) |
| `SVCIMG` | string | (empty) | When set, only run `postinst/<SVCIMG>.sh` |
| `PUBLISH` | string | (empty) | Port mappings (used by SMOLerfile parser for EXPOSE) |

**Conditional variables** (Makefile syntax in options.mk):
```makefile
.if defined(MINIMIZE) && ${MINIMIZE} == y
ADDPKGS=pkgin pkg_tarup pkg_install sqlite3 rsync curl
.endif
```

### 5.2 etc/rc — Runtime Init Script

This is the heart of every service. Standard structure:

```sh
#!/bin/sh

. /etc/include/basicrc          # Mandatory: env, networking, devices
. /etc/include/mount9p          # Optional: host directory sharing

# tmpfs mounts for writable overlays
mount -t tmpfs -o -s10M tmpfs /tmp
mount -t tmpfs -o -s10M tmpfs /var/log
mount -t tmpfs -o -s1M tmpfs /var/run
mount -t tmpfs -o -s10M -o union tmpfs /etc

# Service-specific setup (users, permissions, config)
useradd -m sshd
mkdir -p /home/sshd/.ssh

# Start services
/etc/rc.d/sshd onestart

# Main command (blocks until service exits)
exec myapp

. /etc/include/shutdown         # Clean halt
```

**Key hooks in basicrc:**
- `/etc/rc.pre` — custom pre-boot hook (sourced before device setup)
- `/etc/rc.local` — custom post-boot hook (sourced after networking, before MOUNTRO)
- `SSL_CERT_FILE` env var — if set, copies custom SSL certs and runs `certctl rehash`

### 5.3 postinst/*.sh — Build-Time Scripts

These execute **on the build host** (or builder VM) inside the mounted image root. Use for:
- Downloading external binaries with `curl` or `ftp`
- Extracting archives
- Setting up chroot environment
- Pre-configuration that doesn't need pkgin

They are NOT run inside the microVM at boot time.

**Important conventions:**
- Scripts run from the **mounted image root** (i.e., `pwd` is the fake root)
- Paths like `etc/ssh/` refer to the image's `/etc/ssh/`
- Use `../service/<name>/etc/` to access files from the service directory
- Source `../service/common/funcs` for `rsynclite()` and `../service/common/choupi` for emoji output
- Check `/BUILDIMG` marker file to verify running inside the builder VM

### 5.4 own.mk — User Overrides

Not committed to git. Same format as `options.mk`. Loaded **after** `options.mk` so it overrides. Use for personal dev settings.

```makefile
# service/myapp/own.mk (git-ignored)
IMGSIZE=1024
ADDPKGS=pkgin curl vim
```

### 5.5 sailor.vars (in service/common/)

Seed variables consumed by sailor when `mkimg.sh` runs minimization (see §13.2). Current contents:

- `shippath` — the smolBSD build drive path (`/drive2`), where sailor finds the image being minimized
- `shipbins` — baseline list of binaries always kept (init, mount, sh, useradd, login, `/usr/lib/security/*`, …)
- `sync_dirs` — directories kept in sync rather than stripped (`/etc`, certs, pkgin config, terminfo, zoneinfo, `/var/log`)
- `packages` — package names treated as ship targets (`curl`, `rsync`)

**Relationship:** treat `sailor.vars` as the **floor**, and per-service `sailor.conf` as the **diff** on top of it. If a stripped image later fails in surprising ways (WAPBL errors, missing PAM modules, broken `login`), the fix is almost always to add a keep-rule in `sailor.vars` or the service's own `sailor.conf`, not to patch `mkimg.sh` — see §20.

### 5.6 packages/ — Offline Binary Packages

Place pre-built `.tgz` packages here. `mkimg.sh` rsyncs them to the image root as `/packages/`. The `pkgin` common script detects `/packages/` and installs them via `pkg_add`.

### 5.7 NETBSD_ONLY — Platform Marker

If this empty file exists, `mkimg.sh` refuses to build on non-NetBSD hosts:
```
This image must be built on NetBSD!
Use the image builder instead: make SERVICE=<name> build
```

---

## 6. Build Pipeline — Deep Dive

### 6.1 Image Creation (bmake SERVICE=foo build)

The `build` target in the Makefile orchestrates a two-stage process:

**Stage 1: Builder microVM creation**
```
bmake buildimg
```
1. `SERVICE=build IMGTAG= base` — calls `mkimg.sh` to create `images/build-amd64.img`
2. Extracts `base` + `etc` sets (plus partial `comp:/usr/bin/strip`) with `MOUNTRO=y`
3. Creates FFS (NetBSD) or ext2 (Linux) filesystem on the image
4. Installs the builder's own `/etc/rc` that waits for a second drive and executes build commands

**Stage 2: Service build inside builder VM**
```
bmake SERVICE=foo build
```
1. `fetchall` — download sets, packages, and kernel
2. Creates a blank disk image of `IMGSIZE` MB (via `dd`)
3. Writes `ENVVARS` to `tmp/build-foo` (lock/coordination file)
4. Launches the builder VM with `startnb.sh`:
   - `-k kernels/netbsd-SMOL` — PVH kernel
   - `-i images/build-amd64.img` — builder rootfs
   - `-l images/foo-amd64.img` — second drive (target image; `-l` also accepts a comma-separated list for multiple extra drives)
   - `-w .` — 9P share of project directory
   - `-p ::22022-:22` — SSH access
   - `-c $BUILDCPUS -m $BUILDMEM` (defaults 2 cores / 1024 MB)
   - `-x "-pidfile qemu-<service>.pid"`
5. Builder VM's `/etc/rc` detects the second drive, sources `tmp/build-foo`, calls `make base` to invoke `mkimg.sh` to populate the target image
6. Builder removes `tmp/build-foo` when done (a final `cat` keeps the VM alive after)
7. Host polls the lock file, then kills builder QEMU via the pidfile
8. If `MINIMIZE` is set, waits for the image to be released (`lsof`), then resizes via `qemu-img resize --shrink $(cat tmp/<img>.size)` — **if the image also uses WAPBL journaling, see §20.1**
9. Writes signature to image and `.sig` file: `smolsig:DD/MM/YYYY|UUID`

### 6.2 mkimg.sh — Internal Flow

1. Source `tmp/build-*` for ENVVARS (SERVICE, ARCH, PKGVERS, etc.)
2. Source `service/common/vars`, `funcs`, `choupi`
3. Detect OS: NetBSD (a smolBSD builder image reports `smolBSD` — both accepted), Linux (ext2 path), FreeBSD (gpart/mdconfig path). OpenBSD, macOS and anything else **exit 1**. `MINIMIZE` or a `NETBSD_ONLY` marker also aborts on non-NetBSD hosts.
4. If `FROMIMG` is set, copy existing image (or `dd` onto the secondary disk); otherwise `dd` zero-filled image (host path only)
5. **Partition and format:**
   - **Linux**: `sgdisk` + `losetup` + `mke2fs -O none` (ext2, no journal)
   - **FreeBSD**: `gpart` + `mdconfig` + `newfs` (FFS)
   - **NetBSD**: `gpt` + `vndconfig`/`dkctl` wedge lookup + `newfs` (FFS). WAPBL log is only enabled when **not** MINIMIZE (`noatime` always; this is the guard behind §20.1)
6. Extract ADDPKGS packages into `${LOCALBASE}` (e.g., `/usr/pkg`); exception: with sailor minimization requested, packages are cleanly reinstalled via `pkgin` from `/tmp/usrpkg.tgz` (backed up by the builder VM's `/etc/rc`)
7. If `MINIMIZE` + `sailor.conf` exists + `/var/db/pkgin` present: run sailor — `cd ${BASEPATH}/sailor && ./sailor.sh build /service/<svc>/sailor.conf` (seeded by `service/common/sailor.vars`, see §5.5)
8. Extract sets (`tar xfp`) — supports partial extraction (`set:path`); or copy a hand-made `rootdir` tar
9. **Write `/etc/fstab` atomically** (single full-content write): `NAME=<svc>root / <fs> <opts> 1 1` — **see §20.2 for a real corruption bug if this step is touched**
10. Rsync `service/<svc>/etc/` → mounted `/etc/`
11. Rsync `service/common/` → mounted `/etc/include/`
12. Rsync `service/<svc>/packages/` → mounted `/` (as `/packages/`)
13. Copy kernel if specified (`-k`, to `/netbsd`)
14. **cd into mounted root**; rescue symlink shims; run `postinst/*.sh` scripts sequentially (sorted by `ls`, `sh $x`, `SVCIMG` filter)
15. On non-NetBSD: backup `MAKEDEV` to `etc/`, patch `unionfs` out of `dev/MAKEDEV` (atomic `mv`)
16. Write `PKGVERS` to `etc/pkgvers`
17. If `CURLSH` set: `curl -sSL | /bin/sh`
18. If `MINIMIZE`: clean `/var/db/pkgin`
19. Create `/var/qemufwcfg` mount point
20. If BIOS boot: copy `/usr/mdec/boot`, create `boot.cfg`
21. Unmount; if `MINIMIZE`: `du -s` + `resize_ffs -y -s` + `fsck_ffs -c4 -f -y`, write new size in bytes to `tmp/<img>.size`
22. Detach loopback/vnd; if BIOS boot (NetBSD only): `gpt biosboot -i 1` + `installboot /usr/mdec/bootxx_ffsv1`

**Mount point selection:**
- Host build (no secondary disk): `mnt/` directory in project root
- Builder VM (secondary disk): `/drive2` (from `service/common/vars`)

### 6.3 Builder VM (service/build/)

The builder VM is a special service that:
1. Sources `basicrc` and `mount9p` for networking and host sharing
2. Sets up SSL certificates for HTTPS fetching (tmpfs `/etc/openssl` + `certctl rehash`)
3. Sources `tmp/build-*` to get the target service's build variables
4. If `MINIMIZE` + `sailor.conf`: mounts tmpfs on `/var/db` and `/usr/pkg`, backs up `/usr/pkg` to `/tmp/usrpkg.tgz` (consumed by mkimg.sh's sailor path), and warns if the `sailor/` clone is missing
5. Calls `make <exported vars> base` to invoke `mkimg.sh` for the target service (`ADDPKGS` is excluded from the make invocation)
6. Removes `tmp/build-*` when done (signals the host to kill the VM), then waits on `cat`

---

## 7. Boot / Runtime Pipeline — Deep Dive

### 7.1 startnb.sh — VM Launcher

**Key flags:**

| Flag | Argument | Description |
|------|----------|-------------|
| `-f` | config file | Load VM config (sources the file; may define kernel, img, hostfwd, imgtag, use_pty, KERNEL, NBIMG, …) |
| `-k` | kernel path | Kernel to boot (defaults by arch) |
| `-i` | image path | Root disk image path |
| `-I` | (none) | Load image as initrd instead of disk |
| `-c` | N | Number of CPU cores (default: 1) |
| `-m` | MB | Memory in MB (default: 256) |
| `-r` | root name | Root disk wedge name for the `root=` kernel parameter (default: `NAME=<svc>root`) |
| `-l` | drive2,drive3,… | Extra drives (beyond root) passed to the guest as virtio-blk devices. Comma-separated list, and repeated `-l` flags accumulate. Each drive gets a unique `hd-<uuid>N` id. Mount points inside the guest are up to the service (`/drive2` etc., see `service/common/vars`) |
| `-p` | ports | Port forwarding: `[tcp|udp]:[hostaddr]:hostport-[guestaddr]:guestport` (protocol defaults to tcp) |
| `-n` | N | Number of additional VirtIO console sockets. Creates N host socket files (`s-<uuid>-p<1..N>.sock` in CWD) which map to guest `/dev/ttyVI01`..`ttyVIN` (device nodes are created by basicrc, not by startnb.sh) |
| `-w` | path | 9P host directory to share with guest |
| `-e` | k=v,… | Export variables via QEMU fw_cfg (`opt/org.smolbsd.var.*`) |
| `-E` | f=path,… | Export files via QEMU fw_cfg (`opt/org.smolbsd.file.*`) |
| `-P` | (none) | Use PTY console; `startnb.sh` attaches `picocom -q -b 115200` by default. If `use_pty` in the config file is set to a command (not `y`), that command is used instead |
| `-d` | (none) | Daemonize QEMU |
| `-b` | (none) | Bridge networking (tap interface) |
| `-N` | (none) | Disable networking |
| `-s` | (none) | Share image read-write (don't lock) |
| `-t` | port | TCP serial port (telnet) |
| `-a` | params | Append kernel boot parameters |
| `-x` | args | Extra raw QEMU arguments |
| `-v` | (none) | Verbose (print QEMU command, don't execute) |
| `-u` | (none) | Non-colorful output (sets `CHOUPI=`; the ASCII fallback branch in choupi is `CHOUPI=n`) |
| `-h` | (none) | Show usage |

**Environment variables:**
- `QEMU_ACCEL` — force a specific accelerator (`kvm`, `hvf`, `nvmm`, `tcg`)
- `QEMU` — override QEMU binary (default: `qemu-system-<machine>`)
- `ARCH` — override architecture detection

**Architecture-specific QEMU invocation:**

| Arch | Machine | CPU | Accelerator | Default Kernel |
|------|---------|-----|-------------|----------------|
| x86_64 | `-M microvm,rtc=on,acpi=off,pic=off` | `host,+invtsc` | kvm/nvmm/hvf | `kernels/netbsd-SMOL` |
| i386 | `-M microvm,…` | `host,+invtsc` | kvm/nvmm | `kernels/netbsd-SMOL386` |
| aarch64 | `-M virt,gic-version=host` (host only when KVM present, else `gic-version=3`) | `host` | kvm/hvf | `kernels/netbsd-SMOL-aarch64.img` |

CPU overrides: `QEMU_ACCEL=tcg` forces `qemu64` (x86) or `max` (aarch64) instead of `host`; on macOS Intel, `cputype` is always forced to `qemu64`.

**Console detection:**
- Checks kernel symbols for `viocon_earlyinit` via `nm`
- If found: uses VirtIO console (`virtio-serial-device` + `virtconsole`)
- If not: falls back to ISA serial console (`-serial stdio` or `-serial pty`)

**Port forwarding format transformation:**
```
# User input:   ::8080-:80
# Transformed:  hostfwd=tcp::8080-:80
```
The `-p` flag is processed by `sed` into QEMU `hostfwd=` syntax. The protocol prefix (`tcp:`, `udp:`) is optional and defaults to `tcp`. Multiple comma-separated pairs in one `-p` are all transformed.

**PTY mode:**
When `-P` is passed:
1. QEMU starts with `-daemonize` and writes PTY path to `qemu-<svc>.pty`
2. `startnb.sh` waits for the file, extracts the PTY path, launches `picocom -q -b 115200` (or the custom `use_pty` command)
3. On console exit, kills the QEMU process
4. This is the attach path used for services whose `CMD` runs `login -f` — the PTY console is what makes `login`'s terminal handling behave correctly; see §20.3 for a related failure mode when the image has been minimized

**RTC:** Always `-rtc base=utc,clock=host,driftfix=slew` (UTC, host clock, slew driftfix) — added unconditionally.

**QEMU 9.0/9.1 workaround:** Adds `-L bios -bios bios-microvm.bin` to avoid stack smashing.

### 7.2 PVH Boot Flow

```
QEMU loads netbsd-SMOL kernel directly (no BIOS, no bootloader)
  → Kernel initializes VirtIO MMIO devices
  → Kernel mounts root filesystem (ld0 / dk0 / md0)
  → Kernel executes /etc/rc
    → . /etc/include/basicrc
      → Sets PATH, umask, HOME
      → Checks for md0 (ramdisk root), remounts rw if needed
      → mount -a (reads /etc/fstab)
      → Sources /etc/rc.pre (if exists)
      → Loads qemufwcfg variables (if mount_qemufwcfg available)
      → Creates /dev/MAKEDEV, mounts ptyfs, creates fd and ttyVI* devices
      → Configures vioif0: 10.0.2.15/24, gateway 10.0.2.2, DNS 10.0.2.3
      → Configures lo0 (IPv4 + IPv6)
      → Tunes TCP sendbuf/recvbuf
      → Sources /etc/include/mount9p (if vio9 device present)
      → Handles SSL_CERT_FILE (custom certs + certctl rehash)
      → Sources /etc/rc.local
      → If MOUNTRO: remount / read-only
    → . /etc/include/mount9p (if not already in basicrc)
    → Service-specific commands
    → CMD/ENTRYPOINT
    → . /etc/include/shutdown
      → sync, sync
      → If viocon: remount ro, echo 'JEMATA!' > /dev/ttyVI01
      → Else: umount -af
      → halt -lq
```

### 7.3 VM Control Socket

When `-n N` is used (`N >= 1`):
- Creates N VirtIO console sockets on the host (`s-<uuid>-p<1..N>.sock` in the CWD)
- `/dev/ttyVI01` on the guest is the first socket (p1)
- `startnb.sh` spawns a background process that monitors the p1 socket via `socat`
- When guest writes `JEMATA!` to `/dev/ttyVI01`, the host kills QEMU
- Guest's `shutdown` script uses this for clean host-side teardown

---

## 8. Common Runtime Scripts — Reference

> Snippets below reflect the current code at the version of this doc — they are reference, not specification. If you edit files in `service/common/`, keep §8 in sync.

### 8.1 basicrc (`/etc/include/basicrc` in VM)

```sh
export HOME=/
export PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/pkg/bin:/usr/pkg/sbin:/rescue
umask 022

# Handle ramdisk root (md0) — remount r/w
if [ "$(sysctl -n kern.root_device)" = "md0" ]; then
    mount -u -o rw /dev/md0a /
    sed -i'' 's,^[^ ]*,/dev/md0a,' /etc/fstab
fi

mount -a

# Optional pre-boot hook
[ -f /etc/rc.pre ] && . /etc/rc.pre

# QEMU fw_cfg variables (if mount_qemufwcfg binary exists)
if [ -f /sbin/mount_qemufwcfg ]; then
    dmesg | grep -q qemufwcfg && . /etc/include/qemufwcfg
fi

# Device nodes
[ ! -f "/dev/MAKEDEV" ] && cp -f /etc/MAKEDEV* /dev
if [ -f /sbin/mount_ptyfs ]; then
    mount -t ptyfs ptyfs /dev/pts
    cd /dev && sh MAKEDEV fd && cd -
    /etc/rc.d/ttys start
fi
chmod 666 /dev/null

# VirtIO console extra ports
dmesg | grep -q viocon && \
    (cd /dev && sh MAKEDEV ttyVI01 ttyVI02 && chmod 666 /dev/ttyVI*)

# Static IP (faster than DHCP)
if ifconfig vioif0 >/dev/null 2>&1; then
    route flush -inet6 >/dev/null 2>&1
    ifconfig vioif0 10.0.2.15/24
    route add default 10.0.2.2
    mount | grep read-only || echo "nameserver 10.0.2.3" > /etc/resolv.conf
fi

ifconfig lo0 127.0.0.1 up
ifconfig lo0 inet6 ::1 prefixlen 127 up

# TCP tuning
sysctl -w net.inet.tcp.sendbuf_max=16777216
sysctl -w net.inet.tcp.recvbuf_max=16777216
sysctl -w kern.sbmax=16777216

# 9P mount (if vio9 device present)
. /etc/include/mount9p

# Custom SSL certificates
if [ -n "$SSL_CERT_FILE" ]; then
    [ -d "$SSL_CERT_FILE" ] && cp -R "$SSL_CERT_FILE"/* /usr/share/certs/mozilla/server || \
        cp "$SSL_CERT_FILE" /usr/share/certs/mozilla/server
    certctl rehash 2>/dev/null
fi

# Optional post-boot hook
[ -f /etc/rc.local ] && . /etc/rc.local

# Read-only root if MOUNTRO env var set
[ -n "$MOUNTRO" ] && mount -u -o ro /
```

### 8.2 shutdown (`/etc/include/shutdown`)

```sh
sync; sync
dmesg | grep -q 'viocon0: adding port' && \
    (
        mount -u -o ro /
        sync; sync
        echo 'JEMATA!' > /dev/ttyVI01
    ) || \
umount -af
# no viocon(4) support
halt -lq
```

The `JEMATA!` signal tells the host-side socket monitor to kill QEMU cleanly.

### 8.3 mount9p (`/etc/include/mount9p`)

```sh
[ -z "$MOUNT9P" ] && MOUNT9P=/mnt

if ! mount | grep -q ${MOUNT9P} && dmesg | grep -q vio9; then
    [ -f /etc/MAKEDEV ] && cp /etc/MAKEDEV /dev
    cd /dev && sh MAKEDEV vio9p0
    cd -
    mount_9p -cu /dev/vio9p0 $MOUNT9P
fi
```

### 8.4 qemufwcfg (`/etc/include/qemufwcfg`)

```sh
QEMUFWCFG=/var/qemufwcfg
/sbin/mount_qemufwcfg $QEMUFWCFG

for file in ${QEMUFWCFG}/opt/org.smolbsd.var.*; do
    [ ! -f $file ] && continue
    VARNAME=${file##*.}
    eval "export $VARNAME=\$(cat \$file)"
done
```

### 8.5 funcs (`service/common/funcs`)

```sh
rsynclite()
{
    src=$1; dst=$2
    # Handle --exclude= flags
    # If src is a file: cp -f
    # If src is a directory: tar-based sync (faster than rsync for small trees)
}
```

### 8.6 vars (`service/common/vars`)

```sh
BASEPATH=/mnt       # Project root path (used by builder VM)
DRIVE2=/drive2      # Secondary disk mount point (used by builder VM)
CHOUPI=y            # Enable emoji output
```

### 8.7 choupi (`service/common/choupi`)

Sets emoji or ASCII fallback icons based on `$CHOUPI`:
- `CHOUPI=y` (default): emojis (➡️, ✅, ⚠️, ❌, …)
- `CHOUPI=n`: ASCII fallbacks (>, \, !, X, …)

Also defines `LIGHTGREEN`, `BOLD`, `NORMAL` ANSI color codes.

### 8.8 pkgin (`service/common/pkgin`)

Bootstraps the pkgin package manager from scratch:
1. Detects NetBSD version → derives pkgsrc version
2. Determines architecture URL
3. Installs `pkg_install`, `pkgin`, `pkg_tarup`, `rsync`, `curl` via `pkg_add`
4. Configures repository URL
5. Installs packages from `/packages/` directory if present
6. Installs `$INSTALL_PACKAGES` if set

---

## 9. OCI Registry (Push/Pull with oras)

Default registry: `ghcr.io/netbsdfr/smolbsd`
Override with `SMOLREPO` environment variable.

```bash
# Push
./smoler.sh push myapp-amd64:latest
# → oras push ghcr.io/netbsdfr/smolbsd/myapp-amd64:latest \
#     --artifact-type application/vnd.smolbsd.image \
#     images/myapp-amd64.img:application/x-raw-disk-image

# Pull
./smoler.sh pull myapp-amd64:latest
# → oras pull ghcr.io/netbsdfr/smolbsd/myapp-amd64:latest
#   Downloads myapp-amd64.img to the CURRENT directory — move it to
#   images/ before building on top of or running it

# List images with signature verification
./smoler.sh images          # all images
./smoler.sh images ok       # only images with valid signatures
```

`smoler/img.sh` auto-installs `oras` binary to `bin/oras` if missing. Push/pull only work on Linux and macOS (other OSes are rejected). `images` additionally: reads the `smolsig` from the last 56 bytes of each image, verifies it against the `.sig` file (uuid only), and auto-recreates a missing `.sig` file for signed images (e.g. freshly downloaded ones).

**Image naming:** `<service>-<arch>[:<tag>].img`
- Tag defaults to `latest`
- Signature: `smolsig:DD/MM/YYYY|UUID` appended to image and stored in `.sig` file

---

## 10. GitHub Actions CI/CD

Two workflows in `.github/workflows/`:

### main.yml — builder + rescue images

**Triggers:**
- Push to `main` (ignoring `**.md`, `www/`, `app/`, `.github/workflows/smoler.yml`, `smolerfiles/*`)
- Manual `workflow_dispatch` with inputs: `img`, `arch`, `service`, `mountro`, `curlsh`

**Steps:**
1. Checkout on `ubuntu-latest`
2. `vmactions/netbsd-vm@v1` (release `11`, amd64) boots a real NetBSD VM on the runner; `curl` is installed in `prepare`
3. Inside the NetBSD VM, loop over `arch in amd64 evbarm-aarch64` and build natively (FFS path):
   ```sh
   make SERVICE=<service> CURLSH=<curlsh> ARCH=$arch MOUNTRO=y base
   make SERVICE=rescue ARCH=$arch base   # always build rescue
   ```
   aarch64 is cross-built from the amd64 guest — `base` images are arch-independent (sets + `newfs`, no kernel baked in).
4. Compress all `.img` files on the host with `xz -T0 -9e` + generate SHA256 sums
5. Upload to GitHub Release tag `latest` (pre-release) via `softprops/action-gh-release@v2`

### smoler.yml — SMOLerfile service images

Triggers on push to `smolerfiles/*` (or manual dispatch with a list of files). Builds a fixed set of services (`crush`, `clawd`, `bsdshell`, `nbakery`, `tiny`, `clawlite`, `ttyd`, `maki`, `zeroclaw`) with `smoler.sh build` on plain runners using `QEMU_ACCEL=tcg` (no KVM), after `bmake fetchimg` for amd64 and evbarm-aarch64; publishes to GitHub Packages (`packages: write`). New SMOLerfiles you want CI-tested must be added to the `DFILES` regex in this workflow.

**Note:** CI builds the images natively inside a NetBSD VM (via `vmactions/netbsd-vm`), so the FFS path (WAPBL guard, `resize_ffs`, sailor when `MINIMIZE` + `sailor.conf`) *is* exercised. Only compressing and publishing run on the Linux host. See §20.

---

## 11. BIOS Boot & Bare Metal

When standard PVH boot is unavailable (Bhyve, bare metal, other VMMs):

```bash
# Build with BIOS boot
./smoler.sh build -y -t USB BIOSBOOT=y BIOSCONSOLE=pc smolerfiles/Dockerfile.bsdshell

# Bare metal: dd to USB drive
sudo dd if=images/bsdshell-amd64:USB.img of=/dev/sde bs=1M

# Bhyve/other VMMs: also SMOLIFY the kernel
./smoler.sh build -y -t freebsd BIOSBOOT=y SMOLIFY=y smolerfiles/Dockerfile.bsdshell
```

**BIOS boot internals (in mkimg.sh):**
- Copies `/usr/mdec/boot` to image
- Creates `/boot.cfg` with `timeout=0` and `consdev=${BIOSCONSOLE}`
- After `umount`: `gpt biosboot -i 1 ${imgdev}`, `installboot /dev/r${mountdev} /usr/mdec/bootxx_ffsv1`

**In kernfetch (Makefile):**
- If `BIOSBOOT=y`, downloads `netbsd-GENERIC` kernel
- Copies as `kernels/netbsd-GENERIC.SMOL`
- If `SMOLIFY=y` and `confkerndev` exists: runs confkerndev to keep only essential drivers:
  `mainbus cpu acpicpu ioapic pci isa pcdisplay wsdisplay com virtio ld vioif qemufwcfg`

### confkerndev — Kernel Driver Slimming

A C tool that modifies the kernel ELF binary to **disable device drivers without recompilation**:

```bash
# List all drivers
./confkerndev -i kernels/netbsd-GENERIC

# Keep only specific drivers (write mode)
./confkerndev -i kernels/netbsd-GENERIC.SMOL -w \
    -k mainbus -k cpu -k acpicpu -k ioapic -k pci \
    -k isa -k pcdisplay -k wsdisplay -k com -k virtio \
    -k ld -k vioif -k qemufwcfg

# Disable specific drivers
./confkerndev -i kernels/netbsd-GENERIC.SMOL -w -d foo -k bar

# Read driver list from file
./confkerndev -i kernels/netbsd-GENERIC.SMOL -w -K drivers.txt
```

| Flag | Description |
|------|-------------|
| `-i file` | Input ELF kernel file |
| `-k name` | Keep only this driver (repeatable) |
| `-d name` | Disable this driver (repeatable) |
| `-K file` | Keep drivers listed in file |
| `-D file` | Disable drivers listed in file |
| `-w` | Write mode (mandatory for -k, -d, -K, -D) |
| `-l` | List all driver names (without status) |
| `-v` | Verbose (repeatable for more detail) |
| `-c` | Color output |

---

## 12. Networking Reference

### 12.1 Default QEMU User Network

| Parameter | Value |
|-----------|-------|
| Guest interface | `vioif0` |
| Guest IP | `10.0.2.15/24` |
| Gateway | `10.0.2.2` |
| DNS | `10.0.2.3` |

### 12.2 Port Forwarding Format

**In SMOLerfile:**
```dockerfile
LABEL smolbsd.publish="8881:8880,2289:22"
```

**In config file (`etc/<service>.conf`):**
```sh
hostfwd=::8881-:8880,::2289-:22
```

**Directly with startnb.sh:**
```bash
./startnb.sh -p ::8080-:80 -p tcp::443-:443
```

### 12.3 Bridge Networking

```bash
./startnb.sh -b  # Adds virtio-net-device with tap backend
```

### 12.4 9P Host Directory Sharing

```bash
# Mount current host directory at /mnt in guest
./startnb.sh -w . -i images/myservice-amd64.img

# In SMOLerfile:
VOLUME /data
```

**Platform support:** Available on Linux, NetBSD, macOS. Not supported on FreeBSD/OpenBSD (9p/virtfs not available in their QEMU builds).

---

## 13. Image Minimization

### 13.1 MINIMIZE Modes

| Value | Effect |
|-------|--------|
| `y` | Shrink to actual disk usage + 10% |
| `+512` | Shrink to actual disk usage + 512 MB |
| (unset) | No minimization |

Set via:
- `options.mk`: `MINIMIZE=y` or `MINIMIZE=+256`
- SMOLerfile: `LABEL smolbsd.minimize=y`

### 13.2 Sailor Integration

If `service/<name>/sailor.conf` exists and `MINIMIZE` is set (and `/var/db/pkgin` is present, i.e. inside the builder VM):
- `mkimg.sh` runs the sailor clone in the project root: `cd ${BASEPATH}/sailor && PKG_RCD_SCRIPTS=YES ./sailor.sh build /service/<name>/sailor.conf` (with `TERM=vt220`). The sailor repo must be cloned into `sailor/` first (the builder VM warns if it's missing)
- Seeded by `service/common/sailor.vars`, overlaid by the service's own `sailor.conf` (see §5.5)
- Requires pkgin database (`/var/db/pkgin`) to determine package ownership
- Works only on native NetBSD (sailor is a NetBSD tool)
- **Sailor stripping happens before the `resize_ffs` shrink step in mkimg.sh — this ordering caused the WAPBL failure documented in §20.1. Current guard: mkimg.sh mounts the FFS without the WAPBL log whenever `MINIMIZE` is set. If you're touching this code path, read §20.1 first.**

### 13.3 Minimization Flow

1. After filesystem population, `du -s` measures actual usage (in 512-byte blocks)
2. `addspace` = 10% of usage (`MINIMIZE=y`) or explicit MB × 2048 (`MINIMIZE=+N`)
3. `resize_ffs -y -s ${newsize}` shrinks the filesystem
4. `fsck_ffs -c4 -f -y` verifies
5. New size in bytes written to `tmp/<img>.size` for host-side `qemu-img resize --shrink`

**Caveat:** if the target filesystem was created with WAPBL journaling enabled, step 3 must either disable/flush the journal first or re-lay it out afterward — see §20.1.

---

## 14. Build Environment Variables

Key variables passed through the build chain (`Makefile` → `mkimg.sh` → builder VM):

| Variable | Source | Description |
|----------|--------|-------------|
| `SERVICE` | Makefile | Service name |
| `ARCH` | Makefile/options.mk | Target architecture |
| `PKGVERS` | Makefile/options.mk | Package version |
| `MOUNTRO` | Makefile | Read-only root |
| `BIOSBOOT` | Makefile | BIOS boot mode |
| `PKGSITE` | Makefile | Package fetch URL |
| `ADDPKGS` | Makefile/options.mk | Additional packages |
| `MINIMIZE` | Makefile/options.mk | Minimization setting |
| `BIOSCONSOLE` | Makefile | BIOS console device |
| `FROMIMG` | Makefile/options.mk | Inherit from image |
| `IMGTAG` | smoler/build.sh | Image tag suffix |
| `BUILDARGS` | smoler/build.sh | Dockerfile `--build-arg` overrides |
| `SVCIMG` | Makefile | Filter postinst to specific script |
| `CURLSH` | Makefile/options.mk | URL to finalizer script |

**How variables reach the builder VM:**
1. Makefile writes them to `tmp/build-<SERVICE>` (one per line, `KEY="value"` format)
2. Builder VM's `/etc/rc` sources `tmp/build*`
3. `mkimg.sh` sources `tmp/build*` at the top
4. Variables are available as shell env vars in postinst scripts

---

## 15. Service Patterns & Best Practices

### 15.1 Security
- Always `smolbsd.minimize=y` to reduce attack surface — but check §20.1 first if the service also needs WAPBL
- Mount `/tmp`, `/var/log`, `/var/run` as tmpfs
- Use `MOUNTRO=y` (read-only root) where possible
- Drop root with `USER` directive + `su` in CMD
- Use `SSL_CERT_FILE` env var for custom certificates

### 15.2 Performance
- Include only needed sets in FROM (avoid `man`, `comp` unless required)
- Use `ADDPKGS` for simple binary packages (avoids pkgin overhead)
- Prefer static IP assignment over DHCP (already in basicrc)
- Reuse images via OCI registry

### 15.3 Maintainability
- Document ARG/ENV with comments
- Use `NBUSER`, `NBHOME` conventions for user vars
- Keep postinst scripts idempotent
- Separate build-time (postinst) from runtime (etc/rc)
- Commit `options.mk`, `.gitignore` `own.mk`

### 15.4 Image Size
```dockerfile
FROM base,etc                    # ~10 MB base
LABEL smolbsd.minimize=y         # Strip unused
RUN pkgin up && pkgin -y in curl
RUN rm -rf /var/pkgin/db/* /tmp/*
```

### 15.5 Pattern: Web Service
```dockerfile
FROM base,etc
LABEL smolbsd.service=myweb
LABEL smolbsd.minimize=y
LABEL smolbsd.publish="8080:80"
RUN pkgin up && pkgin -y in nginx
EXPOSE 80
CMD nginx -g 'daemon off;'
```

### 15.6 Pattern: Interactive Shell
```dockerfile
FROM base,etc
LABEL smolbsd.service=myshell
LABEL smolbsd.minimize=y
LABEL smolbsd.use_pty=y
LABEL smolbsd.addpkgs="pkgin pkg_tarup pkg_install sqlite3 rsync curl"
ARG USERNAME=bsd
RUN useradd -m $USERNAME && chsh -s /bin/ksh $USERNAME
CMD login -f -p bsd
```
If this service is also minimized, see §20.3 — `login -f` in a sailor-stripped image is a known sharp edge (missing PAM shared objects, zero-byte utmpx).

### 15.7 Pattern: SSH-Accessible Service
```dockerfile
FROM base,etc
LABEL smolbsd.service=myssh
LABEL smolbsd.publish="2289:22"
RUN useradd -m user && mkdir -p ~user/.ssh
COPY ssh.pub ~user/.ssh/authorized_keys
RUN chown -R user ~user && chmod 700 ~user/.ssh && chmod 600 ~user/.ssh/authorized_keys
CMD /etc/rc.d/sshd onestart && su user -c 'bash'
```

---

## 16. Troubleshooting Reference

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Build fails "set not found" | Missing `etc` in FROM | Use `FROM base,etc` |
| VM boots, no networking | `etc/rc` missing `. /etc/include/basicrc` | Add as first line after shebang |
| Port publishing not working | Wrong LABEL format or host port in use | Check `hostfwd=` in config, verify port free |
| Build fails "pkgin not found" | Missing `comp` set | Use `FROM base,etc,comp` or add `ADDSETS` |
| Image still large after MINIMIZE | Padding is usage +10% (`MINIMIZE=y`); base sets/ADDPKGS too large | Check actual usage (`du` in the image); trim `FROM` sets and `ADDPKGS`, or set an explicit padding with `MINIMIZE=+N` (N MB headroom, not a target size) |
| VM hangs at boot | Missing `. /etc/include/shutdown` or syntax error in rc | Add shutdown, add debug echos |
| SSH refused | sshd not started or wrong key path | Check `/etc/rc` starts sshd, verify COPY path |
| aarch64 image unbootable | Wrong kernel | ARM64 uses `netbsd-SMOL-aarch64.img` (not `netbsd-SMOL`, not GENERIC64) |
| OCI push fails | No auth | Set `GH_TOKEN`, use `oras login` |
| Container exits immediately | CMD not persistent | Use `CMD bash` or `CMD script -c "app" /dev/null` |
| PTY console garbled | Need pty for interactive apps | Set `smolbsd.use_pty=y`, run with `-P` |
| WAPBL/journal errors or fsck failures right after a MINIMIZE build | `resize_ffs` ran on a WAPBL-enabled filesystem after sailor stripped files, invalidating the log metadata | See §20.1 — disable WAPBL before the resize step, or re-init the log after resizing; don't just re-run fsck and hope |
| Boot fails mounting root, or `mount -a` misbehaves oddly on one platform but not others | NUL bytes injected into `/etc/fstab` during the image build | See §20.2 — rebuild fstab with an atomic write, don't append/truncate in place |
| `login -f` fails or hangs in a minimized/sailor-stripped image, but works in an unminimized build of the same service | Sailor stripped PAM shared libraries, and/or `/var/run/utmpx` is zero-byte so `login` can't record the session | See §20.3 — add PAM libs to the sailor keep-list, and ensure the utmpx database is initialized (`setutxdb()`) before first login |
| mount-detection logic (`df`/`mount` parsing) works on Linux/macOS but breaks on NetBSD or vice versa | Compact parameter-expansion one-liner assumed one platform's `mount`/`df` output format | Rewrite as an explicit `if/else` per §21 rather than a single portable-looking expression |
| KVM unavailable on Linux | VirtualBox running or no `/dev/kvm` perms | Stop VirtualBox, check `/dev/kvm` permissions |
| 9P mount fails on FreeBSD | 9p not supported | Use `-w` only on Linux/NetBSD/macOS |

---

## 17. Platform Compatibility Matrix

| Host OS | FFS Support | ext2 Support | Acceleration | Notes |
|---------|------------|--------------|--------------|-------|
| NetBSD | ✅ native | ✅ | NVMM | Full platform; can build builder image; only host that can run sailor |
| Linux | ❌ | ✅ via ext2 | KVM | Uses ext2 for builder, sgdisk for GPT; no sailor |
| macOS | ❌ | ❌ | HVF | mkimg.sh rejects macOS — must `fetchimg` (pre-built builder); no native mkimg.sh |
| FreeBSD | ✅ (gpart/mdconfig/newfs) | ❌ | TCG only | Supported native build host (no sailor); on NetBSD/FreeBSD/Linux the `build` target builds the builder image, elsewhere it fetches it |
| OpenBSD | ❌ | ❌ | TCG only | Not supported as a *build* host (blocked in mkimg.sh); still a target for POSIX-sh compatibility of scripts like smoler.sh |

---

## 18. File Relationships — Quick Reference

```
SMOLerfile (Dockerfile.foo / SMOLerfile.foo / foo.smol)
    │ parsed by smoler/build.sh
    ├── INCLUDE expansion → flat temp file
    ├── LABEL extraction → service/<name>/options.mk
    ├── FROM → SETS= or FROMIMG= in options.mk
    ├── RUN → service/<name>/postinst/postinst-N.sh
    ├── COPY/ADD → rsynclite/ftp commands in postinst
    ├── USER → useradd + chown/chmod in postinst
    ├── ENV/ARG → exports in postinst + etc/rc
    ├── WORKDIR → cd in etc/rc
    ├── CMD/ENTRYPOINT → su <user> -c "cmd" in etc/rc
    ├── VOLUME → share= in etc/<name>.conf + mount9p in etc/rc
    ├── EXPOSE → hostfwd= in etc/<name>.conf (needs smolbsd.publish, or use EXPOSE host:guest shorthand)
    └── SHELL → new postinst-N.sh with different shell

bmake SERVICE=foo build
    ├── fetches sets + kernels + packages
    ├── creates blank .img (dd)
    ├── writes ENVVARS to tmp/build-foo
    ├── launches builder VM with startnb.sh
    ├── builder VM runs mkimg.sh:
    │   ├── partitions + formats .img
    │   ├── extracts ADDPKGS to LOCALBASE
    │   ├── runs sailor if MINIMIZE + sailor.conf (seeded by sailor.vars + sailor.conf)
    │   ├── extracts sets (with partial extraction support)
    │   ├── creates /etc/fstab (atomic write)
    │   ├── rsyncs service/foo/etc → /etc
    │   ├── rsyncs service/common → /etc/include
    │   ├── rsyncs service/foo/packages → /packages
    │   ├── runs postinst/*.sh (sorted by ls)
    │   ├── patches MAKEDEV on non-NetBSD
    │   ├── writes etc/pkgvers
    │   ├── creates /var/qemufwcfg
    │   ├── BIOS boot: copies boot, creates boot.cfg
    │   ├── unmounts, resizes if MINIMIZE
    │   └── BIOS boot: gpt biosboot + installboot
    └── builds images/foo-amd64.img

startnb.sh -f etc/foo.conf
    ├── sources etc/foo.conf (kernel, img, hostfwd, …)
    ├── detects arch → QEMU machine/cpu/accel
    ├── checks kernel for viocon_earlyinit → console type
    ├── constructs QEMU command
    ├── boots VM → /etc/rc → basicrc → CMD → shutdown
    └── monitors viocon socket for JEMATA! (clean shutdown)
```

---

## 19. Key File Signatures / Conventions

- **SMOLerfiles** must end with `.smol`, be named `Dockerfile.*`, or `SMOLerfile.*`
- **`.smol` files**: service name extracted from filename itself (no `LABEL smolbsd.service` needed)
- **`Dockerfile.*` / `SMOLerfile.*`**: service name from `LABEL smolbsd.service=NAME`
- **Service directories** in `service/` match the `SERVICE` variable exactly
- **Kernel naming**: `netbsd-SMOL` (amd64), `netbsd-SMOL386` (i386), `netbsd-SMOL-aarch64.img` (aarch64); BIOS boot uses `netbsd-GENERIC` fetched+gzipped from dist, copied as `netbsd-GENERIC.SMOL` (optionally confkerndev-slimmed)
- **Set archives**: `sets/<arch>/<name>.tar.xz` (amd64/aarch64), `sets/<arch>/<name>.tgz` (i386)
- **Image naming**: `images/<service>-<arch>[:<tag>].img`
- **Config files**: `etc/<service>.conf` (shell-sourced by `startnb.sh -f`)
- **Shell**: All scripts are POSIX sh (not bash). Use `.` not `source`. Use `#!/bin/sh`.
- **Signature format**: `smolsig:DD/MM/YYYY|UUID` (appended to image, stored in `.sig` file)
- **Builder marker**: `/BUILDIMG` file exists inside the builder VM
- **Lock file**: `tmp/build-<SERVICE>` exists while a build is in progress

---

## 20. Debugging Playbook — Known Sharp Edges

These are real failure modes hit during minimization and ARM64 bring-up work on this project. They are easy to misdiagnose from source reading alone because the symptom surfaces several steps downstream of the actual cause. Check here first.

### 20.1 WAPBL journal corruption after MINIMIZE + sailor

**Symptom:** an image built with both `MINIMIZE` and `sailor.conf` boots initially, but either fails `fsck_ffs` on a later boot, logs journal-replay errors, or otherwise behaves as if the WAPBL log is corrupt — even though the build itself reported success.

**Cause:** `mkimg.sh` runs sailor *before* the `resize_ffs` shrink step (§13.2, §13.3). Sailor deletes files that are no longer needed, which changes the filesystem's free-block layout. `resize_ffs` then shrinks the filesystem based on the *post-strip* layout, but the WAPBL log's own metadata (log location, log size markers) isn't recomputed as part of that shrink — it was written when the filesystem was a different size. The log ends up referencing blocks that may no longer mean what it thinks they mean.

**Current status (verified 2026-09-04):** `mkimg.sh` already guards against this — the FFS is mounted **without** the WAPBL log whenever `MINIMIZE` is set (mount options are `noatime,log` only when not minimizing), with the in-code comment "sailor shrink is too agressive, journal is lost". The failure mode below applies if you re-enable the log for MINIMIZE builds, add a post-build step that resizes again, or change the step ordering.

**Fix approach:** don't treat `resize_ffs` as a drop-in "shrink and done" step on a WAPBL-enabled filesystem. Either:
- turn WAPBL off (`fsck_ffs -p` after unmounting with logging disabled, or build without `-o log` in the first place) before resizing, then re-enable logging afterward with a fresh log allocation, or
- run the resize while explicitly forcing a log flush/removal first (unmount cleanly, confirm the log is empty, then resize) rather than resizing a filesystem that still has an active log

Don't just re-run `fsck_ffs -y` repeatedly hoping it converges — if the log metadata is stale relative to the new filesystem size, fsck can paper over symptoms without fixing the root ordering issue. The durable fix is in the mkimg.sh step ordering (§6.2 steps 7 and 21), not in a bigger fsck hammer.

### 20.2 NUL bytes appearing in `/etc/fstab` during image builds

**Symptom:** the built image's `/etc/fstab` contains embedded NUL bytes when inspected with `od -c` or similar, sometimes causing `mount -a` to misparse an entry, most visible as a boot that hangs or mounts the wrong device on one platform but not another.

**Current status (verified 2026-09-04):** fstab is written as a single full-content write (`echo "NAME=… / <fs> <opts> 1 1" > ${mnt}/etc/fstab`, §6.2 step 9) — already atomic; keep it that way if you touch this step. (The guest-side `basicrc` also rewrites fstab at boot for md0 ramdisk roots via `sed -i''` — runtime only, not a build artifact.)

**Cause:** fstab generation in `mkimg.sh` (§6.2 step 9) historically wrote/rewrote the file in place rather than as a single atomic write of the full intended contents. When the file already existed from a `FROMIMG` base or from an earlier partial run, in-place editing (e.g. an overwrite that's shorter than the original content, or a `sed -i` variant that doesn't truncate correctly on all platforms) can leave trailing bytes from the old content, including stray NULs from a previous binary-ish write.

**Fix approach:** always regenerate `/etc/fstab` by writing the complete desired content to a temp file and renaming it into place (`printf ... > fstab.tmp && mv fstab.tmp /etc/fstab`), never by seeking/truncating/appending onto a possibly-stale existing file. Verify with `od -c /etc/fstab` (or `wc -c` vs. expected line lengths) as a build-time sanity check if this class of bug resurfaces.

### 20.3 `login -f` / PAM failures in sailor-stripped images

**Symptom:** `CMD login -f -p someuser` (§15.6 pattern) works fine in an unminimized build, but in the same service built with `MINIMIZE=y` + `sailor.conf`, login either fails outright, drops the connection, or half-authenticates without a proper session.

**Two distinct root causes have been found, often together:**

1. **Missing PAM shared libraries.** Sailor's file-ownership-based stripping doesn't always know that `libpam` and its module `.so`s are needed at runtime by `login`, since they may be dlopen'd rather than linked, so they look "unused" from a static dependency scan and get stripped. Fix: add the PAM libs and modules directory to a keep-rule in the service's `sailor.conf` (or `service/common/sailor.vars` if this should apply everywhere `login` is used).

2. **Zero-byte / uninitialized `/var/run/utmpx`.** In a freshly stripped minimal image, the utmpx database file can end up zero-length instead of properly initialized. `login` (and other utmpx-writing tools) expect the database to already have valid structure; against a zero-byte file, the session-recording call effectively has nothing to write into, which surfaces as a login failure rather than a clear error about the missing database. Fix: ensure utmpx is initialized (equivalent to what `setutxdb()` does) as part of the image build or first boot, before anything tries to log a session — don't assume an empty file is equivalent to an initialized one.

**When debugging this class of issue:** compare an unminimized and a minimized build of the *same* SMOLerfile side by side (`diff` the file lists sailor would strip) rather than guessing — the fix is almost always "add one thing back to the keep-list," not a change to `login` or PAM configuration itself.

---

## 21. Contributor Shell Conventions

All scripts in this project (`smoler.sh`, `mkimg.sh`, `startnb.sh`, everything under `service/common/` and `scripts/`) are **strict POSIX `sh`**, not bash, because they must run unmodified across NetBSD, FreeBSD, OpenBSD, macOS, and Linux hosts. Keep these conventions when editing or adding to them:

- **No bashisms**: no `[[ ]]`, no `(( ))`, no `local`, no arrays, no `$'...'` ANSI-C quoting, no `function` keyword. Use `[ ]`, POSIX arithmetic (`$(( ))` is fine, it's POSIX; `((` as a standalone command is not), and plain `foo() { ... }` function definitions.
- **`printf` over `echo`** for anything with variable content, since `echo` behavior around backslashes and trailing newlines differs across shells/platforms.
- **Prefer explicit `if/else` over compact parameter-expansion one-liners** for anything that branches on platform-specific command output (e.g. detecting mount points, parsing `df`/`mount`/`stat` output). A clever `${var#pattern}`-style one-liner that happens to work on the author's platform is exactly the kind of thing that silently breaks on a different BSD's or Linux's tool output — spell out the platform check and the two branches instead. This has been the direct cause of real portability bugs in smoler.sh's mount-detection logic.
- **Known cross-platform dispatch patterns** already established in the codebase — follow them for any new tool-flag incompatibility you hit:
  - per-OS Makefile variables (see `CKSUM` in the Makefile: `cksum -a sha256 -c` on NetBSD, `sha256sum -c` on Linux, `shasum -a 256 -c` on macOS, `sha256sum -c /dev/stdin` on FreeBSD)
  - `command -v tool` capability checks in shell scripts (e.g. oras auto-install in `smoler/img.sh`)
  - freshness checks are cached by remote `Last-Modified` in `db/` (`scripts/freshchk.sh`), not by file mtime or size — `stat` is avoided precisely because it is not portable
- **Test on all five targets before assuming a fix is portable**: NetBSD, FreeBSD, OpenBSD, macOS, and Linux. A fix verified only on Linux is not verified for this project — see §20.2 and the mount-detection note in §16 for examples of platform-only bugs that shipped because only one platform was tested.
- **Writes to generated files** (`/etc/fstab`, `/etc/rc`, config files under `etc/`) should be **atomic**: build the full content, write to a temp file, then `mv` into place. Don't edit a possibly-stale file in place — see §20.2.
- **CLI style**: options are parsed with `getopts`; repeated list options accumulate — see the `-l drive2,drive3,…` pattern in startnb.sh, which appends via `var="${var}${var:+,}$OPTARG"` and later splits with `tr ',' ' '`. Indent with tabs, end `case` arms with `;;`, one logical operation per line — the NetBSD `/etc/rc.subr` conventions the project follows.
- **Quoting**: quote variables in new code (unquoted expansions are a historical wart, safe only while values have no spaces), but note `eval`-driven command assembly (e.g. the final `cmd` in startnb.sh) is the established pattern for building the QEMU invocation.
- **`set -e`** is used in `mkimg.sh` and `smoler/build.sh` (fail-fast generation) but not in `startnb.sh` or the dispatcher — don't flip it without understanding why.

---

## 22. Agent Decision Guide

When working with smolBSD, follow this decision tree:

### Creating a new service?
1. **Do you want Dockerfile-like syntax?** → Write a `Dockerfile.<name>` in `smolerfiles/`, use `./smoler.sh build`
2. **Do you need fine-grained control?** → Create `service/<name>/` with `options.mk`, `etc/rc`, `postinst/`
3. **Is it a minimal rescue image?** → Start from `service/rescue/` as a template
4. **Do you need the builder VM?** → Use `bmake SERVICE=<name> build` (full pipeline) or `bmake SERVICE=<name> base` (direct mkimg.sh)

### Debugging a build?
1. **Check `tmp/build-*`** for the lock file and exported variables
2. **SSH into the builder VM**: `./startnb.sh -k kernels/netbsd-SMOL -i images/build-amd64.img -p ::22022-:22`
3. **Run mkimg.sh directly**: `bmake SERVICE=<name> base` (skips builder VM)
4. **Check postinst scripts**: They run from the mounted image root; paths are relative to fake `/`

### Debugging a running VM?
1. **Add debug echos** to `etc/rc` before the failing command
2. **Use `-v` flag**: `./startnb.sh -v` to see the full QEMU command
3. **Use `-P` flag** for interactive PTY console
4. **Check basicrc hooks**: `/etc/rc.pre` and `/etc/rc.local` for custom pre/post boot
5. **Use `-e KEY=val`** to pass runtime variables via fw_cfg
6. **Extra disks**: `-l drive2.img,drive3.img` (or repeated `-l`) adds virtio-blk drives; guest mount paths are defined by its `/etc/rc` (`/drive2` is the conventional first one — see `service/common/vars`)

### Documenting a feature or service?
1. **User-facing behavior** (flags, commands, naming): update `README.md` **and** the matching section of this file — `skill/SKILL.md` is the agent-facing reference and must stay in sync with the code
2. **SMOLerfile-based services**: the `smolerfiles/Dockerfile.<name>` file is the primary per-service documentation — keep its ARG/ENV/LABEL comments current
3. **Manual services**: put the rationale in the `service/<name>/` files themselves (comments in `options.mk`, `etc/rc`); there is no per-service README convention
4. **CI-visible SMOLerfiles**: add the file to the `DFILES` regex in `.github/workflows/smoler.yml` or it will not be built/tested

### Fixing a bug in a script?
1. Reproduce on the platform where the bug shows — but verify the fix on at least one other BSD (see §21)
2. Check this file's §16/§20 before assuming a novel bug — several recurring failures are documented sharp edges
3. For build pipeline bugs, instrument `bmake SERVICE=<name> base` (host-only, no builder VM) first; use the full `build` target only when the builder VM itself is in question

### Image too large?
1. Add `LABEL smolbsd.minimize=y` or `MINIMIZE=y`
2. Use `FROM base,etc` (not `base,etc,man,comp`) unless you need extras
3. Add `sailor.conf` for aggressive minimization (NetBSD-only)
4. Clean pkgin cache: `RUN rm -rf /var/db/pkgin/* /tmp/*`
5. Use `ADDPKGS` instead of `pkgin in` for simple packages
