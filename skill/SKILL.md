---
name: smolbsd
description: >
  Complete smolBSD platform expertise — the entire framework for building minimal NetBSD microVMs.
  Covers full lifecycle: SMOLerfile (Dockerfile-compatible) authoring, manual service directory creation,
  the dual build system (smoler.sh high-level vs bmake low-level), mkimg.sh image creation internals,
  startnb.sh QEMU/Firecracker PVH boot (~10ms), OCI registry push/pull (oras), networking & port publishing,
  bidirectional VirtIO sockets, BIOS/baremetal boot with confkerndev kernel slimming,
  GitHub Actions CI/CD pipeline, and every option, script, and convention. Supports amd64, i386, evbarm-aarch64.
compatibility:
  - qemu-system-x86_64 / qemu-system-aarch64
  - bmake (or NetBSD make)
  - tar / bsdtar
  - curl
  - jq
  - bash or ksh
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
  version: "3.0"
  author: iMil / smolBSD community
  last-updated: "2026-05-29"
---

# smolBSD — Complete Platform Reference

This skill provides exhaustive knowledge of the entire smolBSD framework — enough for an agent to understand, navigate, extend, and debug every aspect of the project.

## 1. Project Overview

**smolBSD** builds minimal, fast-booting NetBSD virtual machines (microVMs). Key properties:

- **~10 ms boot** via PVH (PVHv2) on QEMU microvm machine type
- **No prior NetBSD installation** required on the host
- **Immutable by design** — images are built once, booted many times
- **Host platform**: GNU/Linux, NetBSD, macOS (x86 VT-capable or ARM64 CPU recommended)
- **Guest architectures**: `amd64`, `i386`, `evbarm-aarch64`
- **VMMs**: QEMU (primary), Firecracker, Bhyve (BIOS mode)
- **Images** are raw `.img` disk files with FFS (NetBSD) or ext2 (Linux build hosts)

The fundamental unit is a **service** — a directory containing:
- NetBSD set selection (base, etc, comp, man, rescue)
- Build-time scripts (`postinst/*.sh`)
- Runtime init script (`etc/rc`)
- Build configuration (`options.mk`)

---

## 2. Project Directory Layout

```
smolBSD/
├── Makefile              # Entry point for manual image building (bmake)
├── mkimg.sh              # Image creation script (called by Makefile, not directly)
├── startnb.sh            # Low-level QEMU VM launcher
├── smoler.sh             # High-level CLI: build|run|push|pull|images
├── smoler/
│   ├── build.sh          # SMOLerfile parser → generates service dir + calls bmake
│   └── img.sh            # OCI push/pull/list (oras wrapper)
├── scripts/
│   ├── fetch.sh          # Smart curl wrapper (globbing, fresh checks)
│   ├── freshchk.sh       # Checksum-based freshness check
│   └── uname.sh          # Architecture/machine detection helper
├── service/              # All service definitions
│   ├── common/           # Shared runtime scripts bundled into /etc/include/ in VM
│   │   ├── basicrc       # Standard env, networking, devices
│   │   ├── choupi        # Emoji/ASCII toggle for terminal output
│   │   ├── funcs         # rsynclite() helper
│   │   ├── vars          # BASEPATH, DRIVE2 path constants
│   │   ├── shutdown      # Clean halt (sync, umount, optional viocon kill signal)
│   │   ├── mount9p       # 9P filesystem mount (host directory sharing)
│   │   ├── qemufwcfg     # QEMU fw_cfg variable loader
│   │   ├── pkgin         # Package manager bootstrapper
│   │   └── sailor.vars   # Sailor integration variables
│   ├── base/             # Full base+etc system with ksh
│   ├── rescue/           # ~10 MB minimal rescue shell
│   ├── <service>/        # One directory per service
│   │   ├── etc/rc        # Runtime init script (MANDATORY for init(8) services)
│   │   ├── postinst/     # Build-time scripts executed on host/VM builder
│   │   ├── options.mk    # Service build variables (IMGSIZE, ADDPKGS, SETS, etc.)
│   │   ├── own.mk        # User overrides (git-ignored, not committed)
│   │   ├── sailor.conf   # Sailor minimization rules
│   │   ├── packages/     # Pre-built binary packages for offline install
│   │   └── NETBSD_ONLY   # Marker: build only on native NetBSD
├── smolerfiles/          # SMOLerfile / Dockerfile examples
│   ├── Dockerfile.inc    # Shared INCLUDE snippets
│   └── Dockerfile.<name> # Per-service SMOLerfile
├── etc/                  # VM config files for startnb.sh (-f flag)
│   └── <service>.conf    # hostfwd, imgtag, use_pty, KERNEL, NBIMG, etc.
├── bios/                 # BIOS firmware files for microvm machine type
├── confkerndev/          # Kernel driver disabler tool (SMOLIFY)
├── app/                  # Flask-based web GUI for VM management
├── www/                  # Project website and assets
├── k8s/                  # Kubernetes device plugin / deployment examples
├── misc/                 # Miscellaneous documentation
├── contribs/             # Contributed scripts
├── .github/workflows/    # CI/CD pipeline
│   └── main.yml          # Builds images for amd64 + evbarm-aarch64 on push
├── images/               # Built .img disk images (empty in repo, populated at build)
├── kernels/              # Downloaded kernels (empty in repo, populated at build)
├── sets/                 # Downloaded NetBSD sets (empty in repo, populated at build)
├── pkgs/                 # Optional pre-fetched packages (empty in repo, populated at build)
└── mnt/                  # Build-time mount point (empty directory)
```

---

## 3. Two Workflows

### 3.1 smoler.sh (Docker-style, high-level)

| Command | Purpose |
|---------|---------|
| `./smoler.sh build [-y] [-t tag] [--build-arg K=V] [VAR=val] <SMOLerfile>` | Parse SMOLerfile → generate service dir → call `bmake build` |
| `./smoler.sh run <image> [-P] [-m MB] [-c cores] [-p port] [-w path]` | Run a built image (wraps `startnb.sh`) |
| `./smoler.sh push <image>` | Push to OCI registry via oras |
| `./smoler.sh pull <image>` | Pull from OCI registry via oras |
| `./smoler.sh images [ok]` | List local images with size, date, signature verification |

`smoler.sh` is a thin dispatcher:
- `build` → `smoler/build.sh`
- `push|pull|images` → `smoler/img.sh`
- `run` → `startnb.sh` (resolves image name → config file or raw path)

### 3.2 bmake / make (Manual, low-level)

| Command | Purpose |
|---------|---------|
| `bmake buildimg` | Build the builder image (NetBSD/Linux only; uses ext2 on Linux, FFS on NetBSD) |
| `bmake fetchimg` | Download pre-built builder image (macOS, no FFS support) |
| `bmake SERVICE=<name> build` | Build a service image using the builder microVM |
| `bmake SERVICE=<name> base` | Build only the base filesystem (no builder VM — runs `mkimg.sh` directly) |
| `bmake SERVICE=<name> MOUNTRO=y build` | Build with read-only root |
| `bmake SERVICE=<name> ARCH=evbarm-aarch64 build` | Build for ARM64 |
| `bmake kernfetch` | Download the appropriate kernel |
| `bmake setfetch` | Download NetBSD sets |
| `bmake pkgfetch` | Download binary packages |
| `bmake fetchall` | All of the above |
| `bmake rescue` | Shortcut: SERVICE=rescue build |
| `bmake live` | Fetch a full NetBSD live image |

---

## 4. SMOLerfile / Dockerfile Reference

SMOLerfiles are nearly 100% Dockerfile-compatible. `smoler/build.sh` parses them line-by-line and generates:
- `service/<name>/options.mk` — build variables
- `service/<name>/etc/rc`  — runtime init script
- `service/<name>/postinst/postinst-N.sh` — build-time execution scripts
- `etc/<name>.conf` — VM config for `startnb.sh`

### 4.1 All Supported Directives

| Directive | Syntax | Description |
|-----------|--------|-------------|
| `FROM` | `FROM base,etc` or `FROM base-amd64.img` | Mandatory. Comma-separated set names or an existing image name. |
| `LABEL smolbsd.service=NAME` | `LABEL smolbsd.service=caddy` | **Mandatory.** Sets the service name. |
| `LABEL smolbsd.imgsize=N` | `LABEL smolbsd.imgsize=2048` | Image size in MB (default: 512). |
| `LABEL smolbsd.minimize=y` | `LABEL smolbsd.minimize=y` | Shrink to actual usage + 10%. `MINIMIZE=+N` adds N MB instead. |
| `LABEL smolbsd.publish="H:G"` | `LABEL smolbsd.publish="8881:8880,2289:22"` | Port mappings (host:guest), comma-separated. |
| `LABEL smolbsd.use_pty=y` | `LABEL smolbsd.use_pty=y` | Use PTY console (needed for interactive apps like vim/tmux). |
| `LABEL smolbsd.addpkgs="pkg1 pkg2"` | `LABEL smolbsd.addpkgs="pkgin curl"` | Packages to fetch/untar at build time (no pkgin needed). |
| `RUN` | `RUN pkgin up && pkgin -y in caddy` | Execute commands during build (chrooted). Supports heredocs (`<<EOF`). |
| `ARG` | `ARG FOO=bar` | Build argument with optional default. Override with `--build-arg FOO=val`. |
| `ENV` | `ENV NBUSER=clawd` | Set environment variable (available in build scripts and `/etc/rc`). |
| `EXPOSE` | `EXPOSE 8880` | Document exposed ports. Requires `smolbsd.publish` LABEL for actual mapping. |
| `USER` | `USER clawd` | Switch user for subsequent `RUN`, `CMD`, and `COPY` ownership. |
| `WORKDIR` | `WORKDIR /home/clawd` | Set working directory. Adds `cd` to `/etc/rc`. |
| `CMD` | `CMD caddy respond -l :8880` | Default command to run at boot (appended to `/etc/rc`). |
| `ENTRYPOINT` | (same syntax as CMD) | Treated identically to `CMD` in smolBSD. |
| `COPY` | `COPY src dest` | Copy files from build context into image. Supports `--chown`, `--chmod`, `--exclude`. |
| `ADD` | `ADD url dest` | Like `COPY` but also supports HTTP(S) URLs (fetched via ftp). |
| `VOLUME` | `VOLUME /data` | Declare a host directory mount point. Writes `share=` to config. |
| `SHELL` | `SHELL ["/bin/bash", "-c"]` | Change the shell used for `RUN` instructions. The `-c` flag is stripped. |
| `INCLUDE` | `INCLUDE Dockerfile.inc` | **smolBSD extension.** Inline the contents of another file. |

### 4.2 FROM — Set Selection Details

```
FROM base,etc                    # Standard: base system + /etc config files
FROM base,etc,man,comp           # Full: adds man pages and compiler toolchain
FROM comp:/usr/bin/strip         # Partial: only extract /usr/bin/strip from comp set
FROM comp:/usr/libexec/*         # Glob: extract matching files from comp set
FROM base-amd64.img              # Inherit from a pre-built image
```

Valid set names: `base`, `etc`, `man`, `comp`, `rescue`, `games`, `modules`, `tests`, `text`, `xbase`, `xcomp`, `xetc`, `xfont`, `xserver`.

### 4.3 `RUN` — Heredoc Support

```dockerfile
RUN <<EOF
hostname myhost
ulimit -n 4096
echo 'eval \$(resize)' >> /etc/rc.local
EOF
```

The parser detects `<<EOF` (or any tag) and appends lines until the closing tag. Quotes around the tag are stripped.

### 4.4 `COPY` / `ADD` — Options

```dockerfile
COPY --chown=clawd --chmod=600 /host/ssh.pub /home/clawd/.ssh/authorized_keys
ADD --exclude=.git ./src /app
```

### 4.5 Generated `etc/<service>.conf` Format

```sh
hostfwd=::8881-:8880
imgtag=latest
use_pty=
share=/host/path      # from VOLUME
```

---

## 5. Service Directory Manual Reference

### 5.1 `options.mk` — All Known Variables

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
| `BIOSCONSOLE` | string | `com0` | Console device for BIOS boot (com0, pc) |
| `SMOLIFY` | y | (empty) | Run confkerndev to disable unused kernel drivers |
| `FROMIMG` | string | (empty) | Inherit from existing image instead of sets |
| `PKGVERS` | string | `11.0` | Package version for pkgsrc URL |
| `ARCH` | string | (detected) | Target architecture: `amd64`, `i386`, `evbarm-aarch64` |
| `CURLSH` | string | (empty) | URL to a shell script executed as finalizer |
| `SETSEXT` | string | `tar.xz` | Set archive extension (`tgz` for i386) |
| `IMGTAG` | string | (empty) | Suffix appended to image name |
| `SVCIMG` | string | (empty) | When set, only run `postinst/<SVCIMG>.sh` |

### 5.2 `etc/rc` — Runtime Init Script

This is the heart of every service. It must:

1. **Source `basicrc`** for environment, networking, devices
2. Optionally source `mount9p` for host directory sharing
3. Optionally run `/etc/rc.pre` (custom pre-boot)
4. Mount any additional filesystems (tmpfs for /tmp, /var/log, etc.)
5. Create users, set permissions
6. Start services (`sshd`, `bozohttpd`, etc.)
7. Execute the `CMD` (if defined via SMOLerfile)
8. End with `. /etc/include/shutdown` for clean halt

### 5.3 `postinst/*.sh` — Build-Time Scripts

These execute **on the build host** (or builder VM) inside the mounted image root. Use for:
- Downloading external binaries with `curl` or `ftp`
- Extracting archives
- Setting up chroot environment
- Pre-configuration that doesn't need pkgin

They are NOT run inside the microVM at boot time.

### 5.4 `own.mk` — User Overrides

Not committed to git. Same format as `options.mk`. Loaded after `options.mk` so it overrides. Use for personal dev settings.

---

## 6. Build Pipeline — Deep Dive

### 6.1 Image Creation (`bmake SERVICE=foo build`)

The `build` target in the Makefile orchestrates a two-stage process:

**Stage 1: Builder microVM creation**
```
bmake buildimg
```
1. `SERVICE=build IMGTAG= base` — calls `mkimg.sh` to create `images/build-amd64.img`
2. Extracts `base.tgz` + `etc.tgz` sets
3. Creates FFS (NetBSD) or ext2 (Linux) filesystem on the image
4. Installs the builder's own `/etc/rc` that waits for a second drive and executes build commands

**Stage 2: Service build inside builder VM**
```
bmake SERVICE=foo build
```
1. `setfetch` — download `sets/amd64/base.tar.xz`, `etc.tar.xz`
2. `pkgfetch` — download packages listed in `ADDPKGS`
3. `kernfetch` — download the SMOL kernel
4. Creates a blank disk image of `IMGSIZE` MB (via `dd`)
5. Writes `ENVVARS` to `tmp/build-foo` (lock/coordination file)
6. Launches the builder VM with `startnb.sh`:
   - `-k kernels/netbsd-SMOL` — PVH kernel
   - `-i images/build-amd64.img` — builder rootfs
   - `-l images/foo-amd64.img` — second drive (target image)
   - `-w .` — 9P share of project directory
   - `-p ::22022-:22` — SSH access
7. Builder VM's `/etc/rc` detects the second drive, sources `tmp/build-foo`, calls `mkimg.sh` to populate the target image
8. Builder removes `tmp/build-foo` when done
9. Host detects lock file removal → kills builder QEMU
10. If `MINIMIZE` is set, resizes image (via `tmp/<img>.size`)
11. Writes signature to image and `.sig` file: `smolsig:DD/MM/YYYY|UUID`

### 6.2 `mkimg.sh` — Internal Flow

1. Source `tmp/build-*` for ENVVARS (SERVICE, ARCH, PKGVERS, etc.)
2. Source `service/common/vars`, `funcs`, `choupi`
3. Detect OS: NetBSD, Linux (ext2), macOS/FreeBSD/OpenBSD (unsupported)
4. If `FROMIMG` is set, copy existing image; otherwise `dd` zero-filled image
5. Partition and format:
   - **Linux**: `sgdisk` + `losetup` + `mke2fs`
   - **NetBSD**: `gpt` + `dkctl` + `newfs` (FFS)
6. Extract sets (`tar xfp`) into mount point
7. Extract ADDPKGS packages into `${LOCALBASE}` (e.g., `/usr/pkg`)
8. If `MINIMIZE` + `sailor.conf` exists: run sailor to strip unused files
9. Rsync `service/<svc>/etc/` → mounted `/etc/`
10. Rsync `service/common/` → mounted `/etc/include/`
11. Rsync `service/<svc>/packages/` → mounted `/`
12. Copy kernel if specified (`-k`)
13. cd into mounted root; run `postinst/*.sh` scripts sequentially
14. Create `/etc/fstab` entry
15. On Linux: backup `MAKEDEV`, patch unionfs out
16. If `CURLSH` set: fetch and pipe to shell
17. If `MINIMIZE`: clean `/var/db/pkgin`
18. Create `/var/qemufwcfg` mount point
19. If BIOS boot: copy `/usr/mdec/boot`, create `boot.cfg`
20. Unmount, optionally resize with `resize_ffs`, write size info
21. Detach loopback/vnd
22. If BIOS boot: `gpt biosboot` + `installboot`

---

## 7. Boot / Runtime Pipeline — Deep Dive

### 7.1 `startnb.sh` — VM Launcher

**Key flags:**

| Flag | Argument | Description |
|------|----------|-------------|
| `-f` | config file | Load VM config (sources the file) |
| `-k` | kernel path | Kernel to boot (defaults by arch) |
| `-i` | image path | Root disk image path |
| `-I` | (none) | Load image as initrd instead of disk |
| `-c` | N | Number of CPU cores (default: 1) |
| `-m` | MB | Memory in MB (default: 256) |
| `-p` | ports | Port forwarding: `[tcp]:[hostaddr]:hostport-[guestaddr]:guestport` |
| `-n` | N | Number of VirtIO console sockets (creates `/dev/ttyVI01`..N) |
| `-w` | path | 9P host directory to share with guest |
| `-e` | k=v,… | Export variables via QEMU fw_cfg (`opt/org.smolbsd.var.*`) |
| `-E` | f=path,… | Export files via QEMU fw_cfg (`opt/org.smolbsd.file.*`) |
| `-P` | (none) | Use PTY console + picocom |
| `-d` | (none) | Daemonize QEMU |
| `-b` | (none) | Bridge networking (tap interface) |
| `-N` | (none) | Disable networking |
| `-s` | (none) | Share image read-write (don't lock) |
| `-t` | port | TCP serial port (telnet) |
| `-a` | params | Append kernel boot parameters |
| `-x` | args | Extra raw QEMU arguments |
| `-v` | (none) | Verbose (print QEMU command, don't execute) |

**Architecture-specific QEMU invocation:**

| Arch | Machine | CPU | Accelerator | Default Kernel |
|------|---------|-----|-------------|----------------|
| x86_64 | `-M microvm,rtc=on,acpi=off,pic=off` | `host,+invtsc` | kvm/nvmm/hvf | `kernels/netbsd-SMOL` |
| i386 | `-M microvm,…` | `host,+invtsc` | kvm/nvmm | `kernels/netbsd-SMOL386` |
| aarch64 | `-M virt,highmem=off,gic-version=3` | `max` or `host` | kvm/hvf | `kernels/netbsd-GENERIC64.img` |

**Console detection:**
- Checks kernel symbols for `viocon_earlyinit` via `nm`
- If found: uses VirtIO console (`virtio-serial-device` + `virtconsole`)
- If not: falls back to ISA serial console (`-serial stdio` or `-serial pty`)

**Port forwarding format transformation:**
```
# User input:   ::8080-:80
# Transformed to QEMU:  hostfwd=tcp::8080-:80
```
The `-p` flag is processed by sed into QEMU `hostfwd=` syntax.

**PTY mode:**
When `-P` is passed:
1. QEMU starts with `-daemonize` and writes PTY path to `qemu-<svc>.pty`
2. `startnb.sh` waits for the file, extracts the PTY path, launches `picocom`
3. On picocom exit, kills the QEMU process

### 7.2 PVH Boot Flow

```
QEMU loads netbsd-SMOL kernel directly (no BIOS, no bootloader)
  → Kernel initializes VirtIO MMIO devices
  → Kernel mounts root filesystem (ld0 / dk0 / md0)
  → Kernel executes /etc/rc
    → . /etc/include/basicrc
      → Sets PATH, umask
      → Checks for md0 (ramdisk root), remounts rw if needed
      → mount -a (reads /etc/fstab)
      → Sources /etc/rc.pre (if exists)
      → Loads qemufwcfg variables
      → Creates /dev/MAKEDEV, mounts ptyfs, creates fd and ttyVI* devices
      → Configures vioif0: 10.0.2.15/24, gateway 10.0.2.2, DNS 10.0.2.3
      → Configures lo0
      → Tunes TCP sendbuf/recvbuf
      → If MOUNTRO: remount / read-only
      → Sources /etc/rc.local
    → . /etc/include/mount9p (if 9P device present)
    → Service-specific commands
    → CMD/ENTRYPOINT
    → . /etc/include/shutdown
      → sync, sync
      → If viocon: remount ro, echo 'JEMATA!' > /dev/ttyVI01
      → Else: umount -af, halt -lq
```

### 7.3 VM Control Socket

When `-n N` is used (`N >= 1`):
- Creates N VirtIO console sockets on the host
- `/dev/ttyVI01` on the guest is the first socket
- `startnb.sh` spawns a background process that monitors socket 1
- When guest writes `JEMATA!` to `/dev/ttyVI01`, the host kills QEMU
- Guest's `shutdown` script uses this for clean host-side teardown

---

## 8. Common Runtime Scripts — Reference

### 8.1 `basicrc` (`/etc/include/basicrc` in VM)

```
export HOME=/
export PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/pkg/bin:/usr/pkg/sbin
umask 022

# Handle ramdisk root (md0) — remount r/w
if [ "$(sysctl -n kern.root_device)" = "md0" ]; then
    mount -u -o rw /dev/md0a /
    sed -i'' 's,^[^ ]*,/dev/md0a,' /etc/fstab
fi

mount -a

# Optional pre-boot hook
[ -f /etc/rc.pre ] && . /etc/rc.pre

# QEMU fw_cfg variables
dmesg | grep -q qemufwcfg && . /etc/include/qemufwcfg || echo "no qemufwcfg support"

# Device nodes
[ ! -f "/dev/MAKEDEV" ] && cp -f /etc/MAKEDEV* /dev
mount -t ptyfs ptyfs /dev/pts
cd /dev && ./MAKEDEV fd && cd -
/etc/rc.d/ttys start
chmod 666 /dev/null

# VirtIO console extra ports
dmesg | grep -q viocon && (cd /dev && ./MAKEDEV ttyVI01 ttyVI02 && chmod 666 /dev/ttyVI*) || echo "no viocon(4) support"

# Static IP (faster than DHCP)
if ifconfig vioif0 >/dev/null 2>&1; then
    route flush -inet6 >/dev/null 2>&1
    ifconfig vioif0 10.0.2.15/24
    route add default 10.0.2.2
    mount | grep read-only || echo "nameserver 10.0.2.3" > /etc/resolv.conf
fi

ifconfig lo0 127.0.0.1 up

# TCP tuning
sysctl -w net.inet.tcp.sendbuf_max=16777216
sysctl -w net.inet.tcp.recvbuf_max=16777216
sysctl -w kern.sbmax=16777216

# Read-only root if MOUNTRO env var set
[ -n "$MOUNTRO" ] && mount -u -o ro /

# Optional post-boot hook
[ -f /etc/rc.local ] && . /etc/rc.local
```

### 8.2 `shutdown` (`/etc/include/shutdown`)

```
sync; sync
dmesg | grep -q 'viocon0: adding port' && (
    mount -u -o ro /
    sync; sync
    echo 'JEMATA!' > /dev/ttyVI01
) || umount -af
halt -lq
```

### 8.3 `mount9p` (`/etc/include/mount9p`)

```
if dmesg | grep -q vio9; then
    [ -z "$MOUNT9P" ] && MOUNT9P=/mnt
    [ -f /etc/MAKEDEV ] && cp /etc/MAKEDEV /dev
    cd /dev && sh MAKEDEV vio9p0
    cd -
    mount_9p -cu /dev/vio9p0 $MOUNT9P
    echo "➡️ host filesystem mounted on $MOUNT9P"
fi
```

### 8.4 `qemufwcfg` (`/etc/include/qemufwcfg`)

```
QEMUFWCFG=/var/qemufwcfg
/sbin/mount_qemufwcfg $QEMUFWCFG

for file in ${QEMUFWCFG}/opt/org.smolbsd.var.*; do
    [ ! -f $file ] && continue
    VARNAME=${file##*.}
    eval "export $VARNAME=\$(cat \$file)"
done
```

---

## 9. OCI Registry (Push/Pull with oras)

Default registry: `ghcr.io/netbsdfr/smolbsd`  
Override with `SMOLREPO` environment variable.

```bash
# Push
./smoler.sh push myapp-amd64:latest
# → oras push ghcr.io/netbsdfr/smolbsd/myapp-amd64:latest images/myapp-amd64.img

# Pull
./smoler.sh pull myapp-amd64:latest
# → oras pull ghcr.io/netbsdfr/smolbsd/myapp-amd64:latest
#   Places myapp-amd64.img in images/
```

`smoler/img.sh` auto-installs `oras` binary to `bin/oras` if missing. The artifact type is `application/vnd.smolbsd.image`.

Image names follow the pattern: `<service>-<arch>[:<tag>].img`  
Tag defaults to `latest`.

---

## 10. GitHub Actions CI/CD

**File:** `.github/workflows/main.yml`

**Triggers:**
- Push to `main` (ignoring `.md`, `www/`, `app/`)
- Manual `workflow_dispatch` with inputs: `img`, `arch`, `service`, `mountro`, `curlsh`

**Steps:**
1. Checkout on `ubuntu-latest` in privileged Debian container
2. Install prerequisites: `curl xz-utils make sudo git libarchive-tools rsync bmake e2fsprogs gdisk`
3. Build for both `amd64` and `evbarm-aarch64`:
   ```bash
   bmake SERVICE=build ARCH=$arch MOUNTRO=y buildimg
   bmake SERVICE=rescue ARCH=$arch base
   ```
4. Compress all `.img` files with `xz -T0 -9e` + generate SHA256 sums
5. Upload to GitHub Release tag `latest` (pre-release) via `softprops/action-gh-release@v2`

**Build image naming:** `build-amd64.img`, `build-evbarm-aarch64.img` (and rescue variants).

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

**BIOS boot internals (in `mkimg.sh`):**
- Copies `/usr/mdec/boot` to image
- Creates `/boot.cfg` with `timeout=0` and `consdev=${BIOSCONSOLE}`
- After `umount`: `gpt biosboot -i 1 ${imgdev}`, `installboot /dev/r${mountdev} /usr/mdec/bootxx_ffsv1`
- In `kernfetch` (`Makefile`): if `BIOSBOOT=y`, downloads GENERIC kernel, copies it as `<kern>.SMOL`, optionally runs `confkerndev` to disable unused drivers

**confkerndev** (in `confkerndev/`):
- Disables kernel device drivers in the binary ELF (no recompilation)
- `-k driver` keep only listed drivers; `-d driver` disable specific driver; `-K file` read list from file
- `-w` flag required to write changes
- `-v` for verbose output
- Compile with `make` (for amd64) or `make i386` (for 32-bit kernels)

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

If `service/<name>/sailor.conf` exists and `MINIMIZE` is set:
- `mkimg.sh` invokes [sailor](https://github.com/NetBSDfr/sailor) to strip unnecessary files
- Requires pkgin database (`/var/db/pkgin`) to determine package ownership
- Works only on native NetBSD (sailor is a NetBSD tool)

### 13.3 Minimization Flow

1. After filesystem population, `du -s` measures actual usage
2. `addspace` = 10% of usage (MINIMIZE=y) or explicit MB (MINIMIZE=+N)
3. `resize_ffs -y -s ${newsize}` shrinks the filesystem
4. `fsck_ffs -c4 -f -y` verifies
5. New size written to `tmp/<img>.size` for host-side `qemu-img resize --shrink`

---

## 14. Build Environment Variables

Key variables passed through the build chain (`Makefile` → `mkdir.sh` → builder VM):

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
| `BUILDARGS` | smoler/build.sh | Dockerfile --build-arg overrides |

---

## 15. Service Patterns & Best Practices

### 15.1 Security
- Always `smolbsd.minimize=y` to reduce attack surface
- Mount `/tmp`, `/var/log`, `/var/run` as tmpfs
- Use `MOUNTRO=y` (read-only root) where possible
- Drop root with `USER` directive + `su` in CMD

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
| VM boots, no networking | `etc/rc` missing `. /etc/include/basicrc` | Add as first line after header |
| Port publishing not working | Wrong LABEL format or host port in use | Check `hostfwd=` in config, verify port free |
| Build fails "pkgin not found" | Missing `comp` set | Use `FROM base,etc,comp` or add `ADDSETS` |
| Image still large after MINIMIZE | Only 10% reduction | Use `MINIMIZE=+128` for explicit size |
| VM hangs at boot | Missing `. /etc/include/shutdown` or syntax error in rc | Add shutdown, add debug echos |
| SSH refused | sshd not started or wrong key path | Check `/etc/rc` starts sshd, verify COPY path |
| aarch64 image unbootable | Wrong kernel | ARM64 uses `netbsd-GENERIC64.img`, not SMOL |
| OCI push fails | No auth | Set GH_TOKEN, use `oras login` |
| Container exits immediately | CMD not persistent | Use `CMD bash` or `CMD script -c "app" /dev/null` |
| PTY console garbled | Need pty for interactive apps | Set `smolbsd.use_pty=y`, run with `-P` |

---

## 17. Platform Compatibility Matrix

| Host OS | FFS Support | ext2 Support | Acceleration | Notes |
|---------|------------|--------------|--------------|-------|
| NetBSD | ✅ native | ✅ | NVMM | Full platform; can build builder image |
| Linux | ❌ | ✅ via ext2 | KVM | Uses ext2 for builder, sgdisk for GPT; no sailor |
| macOS | ❌ | ❌ | HVF | Must `fetchimg` (pre-built builder); no native mkimg.sh |
| OpenBSD | ❌ | ❌ | TCG only | Not supported (blocked in mkimg.sh) |
| FreeBSD | ❌ | ❌ | TCG only | Not supported (blocked in mkimg.sh) |

---

## 18. File Relationships — Quick Reference

```
SMOLerfile (Dockerfile.foo)
    │ parsed by smoler/build.sh
    ├──→ service/foo/options.mk    (build variables)
    ├──→ service/foo/etc/rc        (runtime init + CMD)
    ├──→ service/foo/postinst/     (build-time scripts)
    └──→ etc/foo.conf              (VM config)

bmake SERVICE=foo build
    ├── fetches sets + kernels
    ├── creates blank .img
    ├── launches builder VM with startnb.sh
    ├── builder VM runs mkimg.sh:
    │   ├── partitions + formats .img
    │   ├── extracts sets
    │   ├── copies service/foo/etc → /etc
    │   ├── copies service/common → /etc/include
    │   └── runs postinst/*.sh
    └── builds images/foo-amd64.img

startnb.sh -f etc/foo.conf
    ├── sources etc/foo.conf (kernel, img, hostfwd, ...)
    ├── detects arch → QEMU machine/cpu/accel
    ├── constructs QEMU command
    └── boots VM → /etc/rc → CMD → shutdown
```

---

## 19. Key File Signatures / Conventions

- **SMOLerfiles** must end with `.smol` or be named `Dockerfile.*`
- **`.smol` files**: parsed differently — `SERVICE` extracted from filename itself
- **Service directories** in `service/` match the `SERVICE` variable exactly
- **Kernel naming**: `netbsd-SMOL` (amd64), `netbsd-SMOL386` (i386), `netbsd-GENERIC64.img` (aarch64)
- **Set archives**: `sets/<arch>/<name>.tar.xz` (amd64/aarch64), `sets/<arch>/<name>.tgz` (i386)
- **Image naming**: `images/<service>-<arch>[:<tag>].img`
- **Config files**: `etc/<service>.conf` (shell-sourced by `startnb.sh -f`)
- **Shell**: All scripts are POSIX sh (not bash). Use `.` not `source`. Use `#!/bin/sh`.
