# BIOS Boot Service

## About

This image is meant to build a _BIOS_ bootable image, for use with _Virtual Machine Managers (VMM)_ that does not support _PXE boot_. It can also be used to setup a bootable device like an _USB_ key.  
Of course, speed will suffer from the typical multi-stage _x86_ boot (_BIOS, bootloader, kernel loading generic kernel_).

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

- _QEMU_ example

```sh
$ qemu-system-x86_64 -accel kvm -m 256 -cpu host -hda images/biosboot-amd64.img
```

- _USB_ key example

```sh
$ [ "$(uname -s)" = "Linux" ] && unit=M || unit=m
$ dd if=images/biosboot-amd64.img of=/dev/keydevice bs=1${unit}
```

And legacy boot on the _USB_ device.

