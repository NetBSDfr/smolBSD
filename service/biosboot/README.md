# BIOS Boot Service

## About

This image is meant to build a _BIOS_ bootable image, for use with _Virtual Machine Managers (VMM)_ that does not support _PVH boot_. It can also be used to setup a bootable device like an _USB_ key.  
Of course, speed will suffer from the typical multi-stage _x86_ boot (_BIOS, bootloader, kernel loading generic kernel_).

## Usage

### Build

```sh
$ bmake SERVICE=biosboot build
```

If you wish to boot with a serial console, set the `BIOSCONSOLE` variable to `com0`:
```sh
$ bmake SERVICE=biosboot BIOSCONSOLE=com0 build
```

### Run

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

### Smoling the `GENERIC` kernel

This service does not use a _SMOL_ kernel, but a _GENERIC_ one as it is intended for real devices or other virtualization systems like _FreeBSD's bhyve_, nevertheless, using [confkerndev][1] you can dramatically reduce _GENERIC_ kernel boot time by disabling all unneeded drivers.  
To do so, simply `git clone https://gitlab.com/0xDRRB/confkerndev` in _smolBSD_ directory and:

```sh
$ cd confkerndev
$ make
```
That's it, _smolBSD_ build system will do the rest.

[1]: https://gitlab.com/0xDRRB/confkerndev
