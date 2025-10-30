#!/bin/bash
# Measures VM boot time by capturing message on Unix socket

set -e

# Parse options
QUIET=false
while [[ "$1" == -* ]]; do
  case "$1" in
    -q|--quiet) QUIET=true; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Define echo function based on quiet flag
if [ "$QUIET" = true ]; then
  log() { :; }  # No-op function
else
  log() { echo "$@"; }
fi

# Default paths (can be overridden via command-line arguments)
KERNEL_PATH="${1:-kernels/netbsd-SMOL}"
DRIVE_PATH="${2:-images/benchmark-amd64.img}"

SOCKET="measure_boot.sock"
MESSAGE_FILE="/tmp/boot_msg.txt"

rm -f "$MESSAGE_FILE" "./$SOCKET"
touch "$MESSAGE_FILE"

log "Kernel: $KERNEL_PATH"
log "Drive: $DRIVE_PATH"

# Generate unique network ID
uuid="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c8)"

START_TIME=$(date +%s.%N)
log "Starting VM at $(date)"

# Start socat server FIRST - listening and ready before QEMU starts
socat UNIX-LISTEN:"./$SOCKET" - > "$MESSAGE_FILE" 2>/dev/null &
SOCAT_PID=$!

log "Socket ready: $SOCKET"

# Start file watcher in parallel BEFORE launching QEMU
if command -v inotifywait >/dev/null 2>&1; then
    timeout 10 inotifywait -e modify -e close_write "$MESSAGE_FILE" >/dev/null 2>&1 &
    WATCH_PID=$!
else
    timeout 10 tail -f "$MESSAGE_FILE" 2>/dev/null | head -1 >/dev/null &
    WATCH_PID=$!
fi

# Launch QEMU directly with our pre-created socket
qemu-system-x86_64 \
  -M microvm,rtc=on,acpi=off,pic=off,accel=kvm \
  -cpu host,+invtsc \
  -smp 1 -m 256 \
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

# Wait for the file watcher to complete
wait $WATCH_PID 2>/dev/null

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
  log "Message received:"
  cat "$MESSAGE_FILE" 2>/dev/null || log "(none)"
  log ""
fi

# Cleanup
kill $SOCAT_PID $VM_PID 2>/dev/null || true
rm -f "$MESSAGE_FILE" "./$SOCKET"

exit 0
