#!/bin/bash
# Measures VM boot time by capturing message on Unix socket

set -e

# Parse options
QUIET=false
while [[ "$1" == -* ]]; do
  case "$1" in
    -q|--quiet) QUIET=true; shift ;;
    -c|--cores) cores="$2"; shift 2 ;;
    -m|--mem) mem="$2"; shift 2 ;;
    -h|--help)
      cat << EOF
Usage: $0 [OPTIONS] [KERNEL_PATH] [DRIVE_PATH]

Measures VM boot time by capturing boot completion message via Unix socket.

Options:
  -q, --quiet       Quiet mode - output only boot time in seconds
  -c, --cores NUM   Number of CPU cores (default: 1)
  -m, --mem SIZE    Memory in MB (default: 256)
  -h, --help        Show this help message

Arguments:
  KERNEL_PATH       Path to kernel (default: arch-specific)
  DRIVE_PATH        Path to disk image (default: arch-specific)

Examples:
  $0                                    # Use defaults
  $0 -q                                 # Quiet mode
  $0 -c 2 -m 512                        # 2 cores, 512MB RAM
  $0 kernels/custom images/custom.img   # Custom paths
EOF
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; echo "Use -h for help" >&2; exit 1 ;;
  esac
done

# Define echo function based on quiet flag
if [ "$QUIET" = true ]; then
  log() { :; }  # No-op function
else
  log() { echo "$@"; }
fi

# Detect OS and architecture
OS=$(uname -s)
MACHINE=$(uname -m)

cputype="host"

case $OS in
NetBSD)
	MACHINE=$(uname -p)
	ACCEL=",accel=nvmm"
	;;
Linux)
	ACCEL=",accel=kvm"
	# Some weird Ryzen CPUs
	[ "$MACHINE" = "AMD" ] && MACHINE="x86_64"
	;;
Darwin)
	ACCEL=",accel=hvf"
	# Mac M1
	[ "$MACHINE" = "arm64" ] && MACHINE="aarch64" cputype="cortex-a710"
	;;
OpenBSD)
	MACHINE=$(uname -p)
	ACCEL=",accel=tcg"
	# uname -m == "amd64" but qemu-system is "qemu-system-x86_64"
	if [ "$MACHINE" = "amd64" ]; then
		MACHINE="x86_64"
	fi
	cputype="qemu64"
	;;
FreeBSD)
	MACHINE=$(uname -p)
	ACCEL=",accel=tcg"
	# uname -m == "amd64" but qemu-system is "qemu-system-x86_64"
	if [ "$MACHINE" = "amd64" ]; then
		MACHINE="x86_64"
	fi
	cputype="qemu64"
	;;
*)
	echo "Unknown hypervisor, no acceleration" >&2
esac

QEMU=${QEMU:-qemu-system-${MACHINE}}

# Set architecture-specific defaults
case $MACHINE in
x86_64|i386)
	mflags="-M microvm,rtc=on,acpi=off,pic=off${ACCEL}"
	cpuflags="-cpu ${cputype},+invtsc"
	mem=${mem:-"256"}
	cores=${cores:-"1"}
	case $MACHINE in
	i386)
		default_kernel="kernels/netbsd-SMOL386"
		default_drive="images/benchmark-i386.img"
		;;
	x86_64)
		default_kernel="kernels/netbsd-SMOL"
		default_drive="images/benchmark-amd64.img"
		;;
	esac
	;;
aarch64)
	mflags="-M virt${ACCEL},highmem=off,gic-version=3"
	cpuflags="-cpu ${cputype}"
	mem=${mem:-"256"}
	cores=${cores:-"1"}
	default_kernel="kernels/netbsd-GENERIC64.img"
	default_drive="images/benchmark-evbarm-aarch64.img"
	;;
*)
	echo "Unknown architecture: $MACHINE" >&2
	exit 1
esac

# Default paths (can be overridden via command-line arguments)
KERNEL_PATH="${1:-$default_kernel}"
DRIVE_PATH="${2:-$default_drive}"

SOCKET="measure_boot.sock"
FIFO="/tmp/boot_fifo_$$"

rm -f "./$SOCKET" "$FIFO"
mkfifo "$FIFO"

log "Architecture: $MACHINE"
log "QEMU: $QEMU"
log "CPU cores: $cores"
log "Memory: ${mem}MB"
log "Kernel: $KERNEL_PATH"
log "Drive: $DRIVE_PATH"

# Generate unique network ID
uuid="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c8)"

START_TIME=$(date +%s.%N)
log "Starting VM at $(date)"

# Start socat server FIRST - listening and ready before QEMU starts
timeout 10 socat UNIX-LISTEN:"./$SOCKET" - 2>/dev/null > "$FIFO" &
SOCAT_PID=$!

log "Socket ready: $SOCKET"

# Launch QEMU directly with our pre-created socket
$QEMU \
  $mflags \
  $cpuflags \
  -smp $cores -m $mem \
  -kernel "$KERNEL_PATH" \
  -append "console=viocon root=ld0a -z" \
  -global virtio-mmio.force-legacy=false \
  -device virtio-blk-device,drive=hd0 \
  -drive if=none,file="$DRIVE_PATH",format=raw,id=hd0 \
  -device virtio-net-device,netdev=net${uuid}0 \
  -netdev user,id=net${uuid}0,ipv6=off \
  -display none \
  -chardev stdio,signal=off,mux=on,id=char0 \
  -device virtio-serial-device,max_ports=2 \
  -device virtconsole,chardev=char0,name=char0 \
  -chardev socket,path=${SOCKET},server=off,id=measure0 \
  -device virtconsole,chardev=measure0,name=measure0 \
  > /dev/null 2>&1 &
VM_PID=$!

log "VM PID: $VM_PID"
log "Waiting for boot message..."

# Read from FIFO (blocks until data arrives)
head -1 < "$FIFO" > /dev/null

END_TIME=$(date +%s.%N)
BOOT_TIME=$(printf "%.9f" $(echo "$END_TIME - $START_TIME" | bc))

if [ "$QUIET" = true ]; then
  echo "$BOOT_TIME"
else
  log ""
  log "========================================="
  log "Boot time: ${BOOT_TIME} seconds"
  log "========================================="
  log ""
fi

# Cleanup
kill $SOCAT_PID $VM_PID 2>/dev/null || true
rm -f "./$SOCKET" "$FIFO"

exit 0
