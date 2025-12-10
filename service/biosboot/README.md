# BIOS Boot Service

## About

This image is meant to build a BIOS bootable image, for use with Virtual Machine Managers that does not support PXE, it can also be used in a bootable device like an USB key.

## Usage

**Build**

```sh
$ bmake SERVICE=biosboot build
```

If you wish to boot with a serial console, set the `BIOSCONSOLE` variable to `com0`:
```sh
$ bmake SERVICE=biosboot BIOSCONSOLE=com0 build
```

**Run**

- QEMU example

```sh
$ qemu-system-x86_64 -accel kvm -m 256 -cpu host -hda images/biosboot-amd64.img
```

- USB key example
```sh
$ [ "$(uname -s)" = "Linux" ] && unit=M || unit=m
$ dd if=images/biosboot-amd64.img of=/dev/keydevice bs=1${unit}
```

And legacy boot on the USB device.

