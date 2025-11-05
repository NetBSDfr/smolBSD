# smolBSD

This project aims at creating a minimal _NetBSD_ 🚩 based _BSD UNIX_ virtual machine that's able to boot and start a service in a couple milliseconds.  
Previous _NetBSD_ installation is not required, using the provided tools the _microvm_ can be
created and started from any _NetBSD_, _GNU/Linux_, _macOS_ system and probably more.

## Kernel

[PVH][4] boot and various optimizations enable _NetBSD/amd64_ and _NetBSD/i386_ to directly boot from a [PVH][4] capable VMM ([QEMU][8] or [Firecracker][9]) in about 10 **milliseconds** on 2025 mid-end x86 CPUs. 

As of June 2025, most of these features are integrated in [NetBSD's current kernel][6], and [NetBSD 11 releases][7] those still pending are available in my [NetBSD development branch][5].

Pre-built 64 bits kernel at https://smolbsd.org/assets/netbsd-SMOL and a 32 bits kernel at https://smolbsd.org/assets/netbsd-SMOL386  

`aarch64` `netbsd-GENERIC64` kernels are able to boot directly to the kernel with no modification

In any case, the `bmake kernfetch` will take care of downloading the correct kernel.

# Usage

## Requirements

- A _GNU/Linux_, _NetBSD_ or _macOS_ operating system (might work on more systems, but not CPU accelerated)
- The following tools installed
  - `curl`
  - `git`
  - `bmake` if running on _Linux_ or _macOS_, `make` on _NetBSD_
  - `qemu-system-x86_64`, `qemu-system-i386` or `qemu-system-aarch64`
  - `sudo` or `doas`
  - `nm` (not used on _macOS_)
  - `bsdtar` on Linux (install with `libarchive-tools` on Debian and derivatives, `libarchive` on Arch)
- A x86 VT-capable, or ARM64 CPU is recommended

## Project structure

- `mkimg.sh` creates a root filesystem image
```sh
$ ./mkimg.sh -h
Usage: mkimg.sh [-s service] [-m megabytes] [-i image] [-x set]
       [-k kernel] [-o] [-c URL]

        Create a root image
        -s service      service name, default "rescue"
        -r rootdir      hand crafted root directory to use
        -m megabytes    image size in megabytes, default 10
        -i image        image name, default rescue-[arch].img
        -x sets         list of NetBSD sets, default rescue.tgz
        -k kernel       kernel to copy in the image
        -c URL          URL to a script to execute as finalizer
        -o              read-only root filesystem
        -u              non-colorful output
```
- `startnb.sh` starts a _NetBSD_ virtual machine using `qemu-system-x86_64` or `qemu-system-aarch64`
```sh
$ ./startnb.sh -h
Usage:  startnb.sh -f conffile | -k kernel -i image [-c CPUs] [-m memory]
        [-a kernel parameters] [-r root disk] [-h drive2] [-p port]
        [-t tcp serial port] [-w path] [-x qemu extra args]
        [-b] [-n] [-s] [-d] [-v] [-u]

        Boot a microvm
        -f conffile     vm config file
        -k kernel       kernel to boot on
        -i image        image to use as root filesystem
        -c cores        number of CPUs
        -m memory       memory in MB
        -a parameters   append kernel parameters
        -r root disk    root disk to boot on
        -l drive2       second drive to pass to image
        -t serial port  TCP serial port
        -n num sockets  number of VirtIO console socket
        -p ports        [tcp|udp]:[hostaddr]:hostport-[guestaddr]:guestport
        -w path         host path to share with guest (9p)
        -x arguments    extra qemu arguments
        -b              bridge mode
        -s              don't lock image file
        -d              daemonize
        -v              verbose
        -u              non-colorful output
        -h              this help
```
- `sets` contains _NetBSD_ "sets" by architecture, i.e. `amd64/base.tgz`, `evbarm-aarch64/rescue.tgz`...
- `pkgs` holds optional packages to add to a microvm, it has the same format as `sets`.

A `service` is the base unit of a _smolBSD_ microvm, it holds the necesary pieces to build a _BSD_ system from scratch.  
- `service` structure:

```sh
service
├── base
│   ├── etc
│   │   └── rc
│   ├── postinst
│   │   └── dostuff.sh
│   ├── options.mk       # Service-specific defaults
│   └── own.mk           # User-specific overrides (not in git)
├── common
│   └── basicrc
└── rescue
    └── etc
        └── rc
```
A microvm is seen as a "service", for each one:

- There **COULD** be a `postinst/anything.sh` which will be executed by `mkimg.sh` at the end of root basic filesystem preparation. **This is executed by the build host at build time**
- If standard _NetBSD_ `init` is used, there **MUST** be an `etc/rc` file, which defines what is started at vm's boot. **This is executed by the microvm**.
- Image specifics **COULD**  be added in `make(1)` format in `options.mk`, i.e.
```sh
$ cat service/nbakery/options.mk
# size of resulting inage in megabytes
IMGSIZE=1024
# as of 202510, there's no NetBSD 11 packages for !amd64
.if defined(ARCH) && ${ARCH} != "amd64"
PKGVERS=10.1
.endif
```
- User-specific overrides **COULD** be added in `own.mk` for personal development settings  (not committed to repository)

In the `service` directory, `common/` contains scripts that will be bundled in the
`/etc/include` directory of the microvm, this would be a perfect place to have something like:

```sh
$ cat common/basicrc
export HOME=/
export PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/pkg/bin:/usr/pkg/sbin
umask 022

mount -a

if ifconfig vioif0 >/dev/null 2>&1; then
        # default qemu addresses and routing
        ifconfig vioif0 10.0.2.15/24
        route add default 10.0.2.2
        echo "nameserver 10.0.2.3" > /etc/resolv.conf
fi

ifconfig lo0 127.0.0.1 up

export TERM=dumb
```

And then add this to your `rc`:
```sh
. /etc/include/basicrc
```

## Considerations

You can build a system using 2 methods:

- using the `base` `Makefile` target, this will build directly on the host, it will use `ext2` as the filesystem if building on a _Linux_ host, and `ffs` if building on a _NetBSD_ host
- using the recommended `build` `Makefile` target, this will fire up a _NetBSD_ builder microvm that will use its own root filesystem and will format the image using `ffs`.

>[!WARNING]
> When using the `base` target, `bmake(1)` will directly use your host to build images, and as `postinst` operations are run as `root` **in the build host: only use relative paths** in order **not** to impair your host's filesystem.

Again, it is **highly recommended** to use the `build` target for any other service than the builder image.

## Prerequisite

For the microvm to start instantly, you will need a kernel that is capable of "direct booting" with the `qemu -kernel` flag.

**For `amd64`/`PVH` and `i386`/`PVH`**

Download the `SMOL` kernel

```sh
$ bmake kernfetch
```

**For `aarch64`**

Download a regular `netbsd-GENERIC64.img` kernel

```sh
$ bmake ARCH=evbarm-aarch64 kernfetch
```

## Image building

In the following examples, replace `bmake` by `make` if you are using _NetBSD_ as the host.

* Either create the builder image if you are running _GNU/Linux_ or _NetBSD_
```sh
$ bmake buildimg
```
* Or by simply fetch it if you are running systems that do not support `ext2` or `ffs` such as _macOS_
```sh
$ bmake fetchimg
```
Both methods will create an `images/build-<arch>.img` disk image that you'll be able to use to build services.  
To create a service image using the builder, execute the following:
```sh
$ bmake SERVICE=nitro build
```
This will spawn a microvm running the build image, and will in turn build the requested service.

## Example of a very minimal (10MB) virtual machine

>[!Note]
> You can use the ARCH variable to specify an architecture to build your image for, default is amd64.

```sh
$ bmake SERVICE=rescue build
```
Will create a `rescue-amd64.img` file for use with an _amd64_ kernel.
```sh
$ bmake SERVICE=rescue MOUNTRO=y build
```
Will also create a `rescue-amd64.img` file but with read-only root filesystem so the _VM_ can be stopped without graceful shutdow. Note this is the default for `rescue` as set in `service/rescue/options.mk`
```sh
$ bmake SERVICE=rescue ARCH=i386 build
```
Will create a `rescue-i386.img` file for use with an _i386_ kernel.
```sh
$ bmake SERVICE=rescue ARCH=evbarm-aarch64 build
```
Will create a `rescue-evbarm-aarch64.img` file for use with an _aarch64_ kernel.

Start the microvm
```sh
$ ./startnb.sh -k kernels/netbsd-SMOL -i images/rescue-amd64.img
```

## Example of an image filled with the `base` set on an `x86_64` CPU

```sh
$ bmake SERVICE=base build
$ ./startnb.sh -k kernels/netbsd-SMOL -i images/base-amd64.img
```

## Example of an image running the `bozohttpd` web server on an `aarch64` CPU

Services are build on top of the `base` set, this can be overriden with the `SETS` `make(1)` variable.  
Service name is specified with the `SERVICE` `make(1)` variable.

```sh
$ make ARCH=evbarm-aarch64 SERVICE=bozohttpd build
$ ./startnb.sh -k kernels/netbsd-GENERIC64.img -i images/bozohttpd-evbarm-aarch64.img -p ::8080-:80
[   1.0000000] NetBSD/evbarm (fdt) booting ...
[   1.0000000] NetBSD 10.99.11 (GENERIC64)     Notice: this software is protected by copyright
[   1.0000000] Detecting hardware...[   1.0000040] entropy: ready
[   1.0000040]  done.
Created tmpfs /dev (1359872 byte, 2624 inodes)
add net default: gateway 10.0.2.2
started in daemon mode as `' port `http' root `/var/www'
got request ``HEAD / HTTP/1.1'' from host 10.0.2.2 to port 80
```
Try it from the host
```sh
$ curl -I localhost:8080
HTTP/1.1 200 OK
Date: Wed, 10 Jul 2024 05:25:04 GMT
Server: bozohttpd/20220517
Accept-Ranges: bytes
Last-Modified: Wed, 10 Jul 2024 05:24:51 GMT
Content-Type: text/html
Content-Length: 30
Connection: close
```

## Example of starting a _VM_ with bi-directionnal socket to _host_

```sh
$ bmake SERVICE=mport MOUNTRO=y build
$ ./startnb.sh -n 1 -i images/mport-amd64.img 
host socket 1: s885f756bp1.sock
```
On the guest, the corresponding socket is `/dev/ttyVI0<port number>`, here `/dev/ttyVI01`
```sh
guest$ echo "hello there!" >/dev/ttyVI01
```
```sh
host$ socat ./s885f756bp1.sock -
hello there!
```
## Example of a full fledge NetBSD Operating System

```sh
$ bmake live # or make ARCH=evbarm-aarch64 live
$ ./startnb.sh -f etc/live.conf
```
This will fetch a directly bootable kernel and a _NetBSD_ "live", ready-to-use, disk image. Login with `root` and no password. To extend the size of the image to 4 more GB, simply do:

```sh
$ dd if=/dev/zero bs=1M count=4000 >> NetBSD-amd64-live.img
```
And reboot.

## Customization

The following `Makefile` variables change `mkimg.sh` behavior:

* `ADDPKGS` will fetch and **untar** the packages paths listed in the variable, this is done in `postinst` stage, on the build host, where `pkgin` might not be available
* `ADDSETS` will add the sets paths listed in the variable
* `MOUNTRO` if set to `y`, the microvm will mount its root filesystem as read-only
* `MINIMIZE` if set to `y`, will invoke [sailor][3] in order to minimize the produced image

The following environment variables change `startnb.sh` behavior:

* `QEMU` will use custom `qemu` instead of the one in user's `$PATH`

## Basic frontend

A simple virtual machine manager is available in the `app/` directory, it is a
`python/Flask` application and needs the following requirements:

* `Flask`
* `psutil`

Start it in the `app/` directory like this: `python3 app.py` and a _GUI_ like
the following should be available at `http://localhost:5000`:

![smolGUI](gui.png)

[0]: https://gitlab.com/0xDRRB/confkerndev
[1]: https://man.netbsd.org/x86/multiboot.8
[2]: https://www.linux-kvm.org/page/Main_Page
[3]: https://github.com/NetBSDfr/sailor
[4]: https://xenbits.xen.org/docs/4.6-testing/misc/pvh.html
[5]: https://github.com/NetBSDfr/NetBSD-src/tree/nbfr_master
[6]: https://github.com/NetBSD/src
[7]: https://nycdn.netbsd.org/pub/NetBSD-daily/netbsd-11/latest
[8]: https://www.qemu.org/docs/master/system/i386/microvm.html
[9]: https://firecracker-microvm.github.io/
