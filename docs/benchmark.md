# Benchmark Tool

The benchmark script measures VM boot time by capturing a boot completion message via Unix socket.

## Usage

```bash
./scripts/benchmark.sh [OPTIONS] [KERNEL_PATH] [DRIVE_PATH]
```

### Options

- `-q, --quiet`: Quiet mode - outputs only the boot time in seconds (useful for scripting)

### Arguments

- `KERNEL_PATH`: Path to the kernel file (default: `kernels/netbsd-SMOL`)
- `DRIVE_PATH`: Path to the disk image (default: `images/benchmark-amd64.img`)

## Examples

### Basic Usage (Verbose Mode)

```bash
$ ./scripts/benchmark.sh
Kernel: kernels/netbsd-SMOL
Drive: images/benchmark-amd64.img
Starting VM at Thu Oct 30 09:45:13 PM CET 2025
Socket ready: measure_boot.sock
VM PID: 35983
Waiting for boot message...

=========================================
Boot time: 0.143655123 seconds
=========================================

Message received:
BOOT_COMPLETE
```

### Quiet Mode

```bash
$ ./scripts/benchmark.sh -q
0.140307116
```

### Custom Kernel and Drive

```bash
# Custom kernel only (uses default drive)
$ ./scripts/benchmark.sh kernels/custom-kernel

# Custom kernel and drive
$ ./scripts/benchmark.sh kernels/custom-kernel images/custom.img

# Quiet mode with custom paths
$ ./scripts/benchmark.sh -q kernels/custom-kernel images/custom.img
```

### Scripting Examples

```bash
# Run multiple benchmarks and calculate average
total=0
runs=10
for i in $(seq 1 $runs); do
  time=$(./scripts/benchmark.sh -q)
  total=$(echo "$total + $time" | bc)
  echo "Run $i: $time seconds"
done
avg=$(echo "scale=9; $total / $runs" | bc)
echo "Average: $avg seconds"

# Compare two different configurations
echo "Configuration A:"
time_a=$(./scripts/benchmark.sh -q kernels/netbsd-SMOL images/config-a.img)
echo "Configuration B:"
time_b=$(./scripts/benchmark.sh -q kernels/netbsd-SMOL images/config-b.img)
diff=$(echo "$time_b - $time_a" | bc)
echo "Difference: $diff seconds"
```

## Requirements

- `qemu-system-x86_64` with KVM support
- `socat` for Unix socket communication
- `bc` for floating-point arithmetic

## How It Works

1. Creates a Unix socket for communication with the VM
2. Starts a `socat` server listening on the socket
3. Launches QEMU with the specified kernel and drive
4. The VM sends "BOOT_COMPLETE" message via virtio console to the socket
5. Measures the time between VM launch and message receipt
6. Cleans up processes and temporary files

## VM Configuration

The benchmark uses QEMU's microvm machine type with:
- KVM acceleration
- 1 CPU core
- 256MB RAM