#!/bin/sh

# Define log function based on quiet flag
log() {
    [ "$QUIET" != "true" ] && echo "$@"
}

setup_benchmark() {
    SOCKET="measure_boot.sock"
    FIFO="/tmp/boot_fifo_$$"

    rm -f "./$SOCKET" "$FIFO"
    mkfifo "$FIFO"

    # Start socat server FIRST - listening and ready before QEMU starts
    timeout 10 socat UNIX-LISTEN:"./$SOCKET" - 2>/dev/null > "$FIFO" &
    SOCAT_PID=$!

    log "Socket ready: $SOCKET"

    START_TIME=$(date +%s.%N)
    log "Starting VM at $(date)"

    # Export variables for parent script
    export BENCHMARK_SOCKET="$SOCKET"
    export BENCHMARK_FIFO="$FIFO"
    export BENCHMARK_START_TIME="$START_TIME"
    export BENCHMARK_SOCAT_PID="$SOCAT_PID"
}

finish_benchmark() {
    # Read from FIFO (blocks until data arrives)
    head -1 < "$BENCHMARK_FIFO" > /dev/null

    END_TIME=$(date +%s.%N)
    BOOT_TIME=$(printf "%.9f" $(echo "$END_TIME - $BENCHMARK_START_TIME" | bc))

    if [ "$QUIET" = "true" ]; then
        echo "$BOOT_TIME"
    else
        log ""
        log "========================================="
        log "Boot time: ${BOOT_TIME} seconds"
        log "========================================="
        log ""
    fi

    # Force kill QEMU and cleanup the socket
    kill $BENCHMARK_SOCAT_PID $BENCHMARK_VM_PID 2>/dev/null || true
    rm -f "./$BENCHMARK_SOCKET" "$BENCHMARK_FIFO"
}

benchmark_extra_chardev() {
    echo "-chardev socket,path=${BENCHMARK_SOCKET},server=off,id=measure0 \
-device virtconsole,chardev=measure0,name=measure0"
}
