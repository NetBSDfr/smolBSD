#!/bin/sh

kernel=$1

img=${2:-"root.img"}

[ -n "$3" ] && \
	drive2="\
		-device virtio-blk-device,drive=smolhd1 \
		-drive file=${3},if=virtio,format=raw,id=smolhd1"

OS=$(uname -s)

case $OS in
Linux)
	ACCEL=",accel=kvm"
	;;
Darwin)
	ACCEL=",accel=hvf"
	;;
NetBSD)
	ACCEL=",accel=nvmm"
	;;
*)
	echo "Unknown hypervisor, no acceleration"
esac

qemu-system-x86_64 \
	-M microvm,x-option-roms=off,rtc=on,acpi=off,pic=off${ACCEL} \
	-m 256 -cpu host,+invtsc \
	-kernel $kernel -append "console=com root=ld0a -z" \
	-serial mon:stdio -display none \
	-device virtio-blk-device,drive=smolhd0 \
	-drive file=${img},format=raw,id=smolhd0 $drive2 \
	-device virtio-net-device,netdev=smolnet0 \
	-netdev user,id=smolnet0,hostfwd=tcp::2022-:22 \
