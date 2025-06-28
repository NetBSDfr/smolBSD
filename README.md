# smolBSD

This project aims at creating a minimal _NetBSD_ virtual machine that's able to boot and
start a service in less than a second.  
Previous _NetBSD_ installation is not required, using the provided tools the _microvm_ can be
created from any _NetBSD_ or _GNU/Linux_ system.

When creating the image on a _NetBSD_ system, the image will be formatted using FFS, when
creating the image on a _GNU/Linux_ system, the image will be formatted using _ext2_.

[PVH][4] boot and various optimizations enable _NetBSD/amd64_ and _NetBSD/i386_ to directly boot from a [PVH][4] capable VMM (QEMU or Firecracker) in a couple **milliseconds**.  

As of June 2025, most of these features are integrated in [NetBSD's current kernel][6], those still pending are available in my [NetBSD development branch][5].  

You can fetch a pre-built 64 bits kernel at https://smolbsd.org/assets/netbsd-SMOL and a 32 bits kernel at https://smolbsd.org/assets/netbsd-SMOL386  
Warning those are _NetBSD-current_ kernels!

`aarch64` `netbsd-GENERIC64` kernels are able to boot directly to the kernel with no modification

# Usage

## Requirements

- A GNU/Linux or NetBSD operating system
- The following tools installed
  - `curl`
  - `git`
  - `make` (GNU Make)
  - `uuid-runtime` (for uuidgen)
  - `qemu-system-x86_64`, `qemu-system-i386` or `qemu-system-aarch64`
  - `sudo` or `doas`
  - `rsync`
  - `nm`
  - `bsdtar` (install with libarchive-tools on linux)
- A x86 VT-capable, or ARM64 CPU is recommended

## Project structure

- `mkimg.sh` creates a root filesystem image
```text
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
```
- `startnb.sh` starts a _NetBSD_ virtual machine using `qemu-system-x86_64` or `qemu-system-aarch64`
```text
Usage:  startnb.sh -f conffile | -k kernel -i image [-c CPUs] [-m memory]
        [-a kernel parameters] [-r root disk] [-h drive2] [-p port]
        [-t tcp serial port] [-w path] [-x qemu extra args]
        [-b] [-n] [-s] [-d] [-v]

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
        -h              this help
```
- `sets` contains _NetBSD_ "sets", i.e. `base.tgz`, `rescue.tgz`...
- `etc` holds common `/etc` files to be installed in the root filesystem
- `service` structure:

```sh
service
├── base
│   ├── etc
│   │   └── rc
│   └── postinst
│       └── dostuff.sh
├── common
│   └── basicrc
└── rescue
    └── etc
        └── rc
```
A microvm is seen as a "service", for each one:

- there **COULD** be a `postinst/anything.sh` which will be executed by `mkimg.sh` at the end of root basic filesystem preparation. **This is executed by the build host at build time**
- there **MUST** be an `etc/rc` file, which defines what is started at vm's boot. **This is executed by the microvm**.

In the `service` directory, `common/` contains scripts that will be bundled in the
`/etc/include` directory of the microvm, this would be a perfect place to have something like:

```shell
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
```shell
. /etc/include/basicrc
```

## ⚠️  Warning ⚠️

`postinst` operations are run as `root` **in the build host: only use relative paths** in order **not** to impair your host's filesystem.

## Prerequisite

For the microvm to start instantly, you will need a kernel that is capable of "direct booting" with the `qemu -kernel` flag.

**For `amd64`/`PVH` and `i386`/`PVH`**

Download the `SMOL` kernel

* 64 bits
```shell
$ curl -O https://smolbsd.org/assets/netbsd-SMOL
```
* 32 bits
```shell
$ curl -O https://smolbsd.org/assets/netbsd-SMOL386
```

**For `aarch64`**

Download a regular `netbsd-GENERIC64.img` kernel

```shell
$ curl -L -o- -s https://nycdn.netbsd.org/pub/NetBSD-daily/HEAD/latest/evbarm-aarch64/binary/kernel/netbsd-GENERIC64.img.gz|gunzip -c >netbsd-GENERIC64.img
```

## Example of a very minimal (10MB) virtual machine

> Note: you can use the ARCH variable to specify an architecture to build your image for, default is amd64.

```shell
$ make rescue
```
Will create a `rescue-amd64.img` file for use with an _amd64_ kernel.
```shell
$ make MOUNTRO=y rescue
```
Will also create a `rescue-amd64.img` file but with read-only root filesystem so the _VM_ can be stopped without graceful shutdow
```shell
$ make ARCH=i386 rescue
```
Will create a `rescue-i386.img` file for use with an _i386_ kernel.
```shell
$ make ARCH=evbarm-aarch64 rescue
```
Will create a `rescue-evbarm-aarch64.img` file for use with an _aarch64_ kernel.

Start the microvm
```shell
$ ./startnb.sh -k netbsd-SMOL -i rescue-amd64.img
```

## Example of an image filled with the `base` set on an `x86_64` CPU

```shell
$ make base
$ ./startnb.sh -k netbsd-GENERIC64.img -i base-evbarm-aarch64.img
```

## Example of an image running the `bozohttpd` web server on an `aarch64` CPU

```shell
$ make ARCH=evbarm-aarch64 SERVICE=bozohttpd base
$ ./startnb.sh -k netbsd-GENERIC64.img -i bozohttpd-evbarm-aarch64.img -p ::8080-:80
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
```shell
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

## Example of an image used to create an nginx microvm with [sailor][3]

```shell
$ make SVCIMG=nginx imgbuilder
```
This will spawn an image builder host which will populate an `nginx` minimal image.

Once the `nginx` image is baked, simply run it:

```shell
$ ./startnb.sh -k netbsd-SMOL -i nginx-amd64.img -p tcp::8080-:80
```

And try it:

```shell
$ curl -I http://localhost:8008
HTTP/1.1 200 OK
Server: nginx/1.24.0
Date: Sun, 30 Jun 2024 07:58:14 GMT
Content-Type: text/html
Content-Length: 615
Last-Modified: Mon, 08 Apr 2024 14:01:28 GMT
Connection: keep-alive
ETag: "6613f8b8-267"
Accept-Ranges: bytes
```

### Example configuration for the `nginx` service

```shell
$ cat service/imgbuilder/postinst/nginx.sh
#!/bin/sh

git clone https://github.com/NetBSDfr/sailor

ship=fakecracker

# create sailor base config - https://github.com/NetBSDfr/sailor
cat >sailor/${ship}.conf<<EOF
shipname=$ship
shippath="/sailor/$ship"
shipbins="/bin/sh /sbin/init /usr/bin/printf /sbin/mount /sbin/mount_ffs /bin/ls /sbin/mknod /sbin/ifconfig /usr/bin/nc /usr/bin/tail /sbin/poweroff /sbin/umount /sbin/fsck /usr/bin/netstat /sbin/dhcpcd /sbin/route"
packages="nginx"
EOF

# system and service startup
mkdir -p sailor/ships/${ship}/etc
cat >>sailor/ships/${ship}/etc/rc<<EOF
. /etc/include/basicrc

# service startup

printf "\nstarting nginx.. "
/usr/pkg/sbin/nginx
echo "done"
printf "\nTesting web server:\n"
printf "HEAD / HTTP/1.0\r\n\r\n"|nc -n 127.0.0.1 80
printf "^D to cleanly shutdown\n\n"
sh

. /etc/include/shutdown
EOF
```
You might also want to add an `service/imgbuilder/etc/rc.nginx`
```
$ cat service/imgbuilder/etc/rc.nginx

# do stuff

cat >${ship}/usr/pkg/share/examples/nginx/html/index.html<<_HTML
<html>
<body>
<pre>
Welcome to $(uname -s) $(uname -r) on $(uname -m) / $(uname -p)!
</pre>
</body>
</html>
_HTML

```

## Example of starting a _VM_ with bi-directionnal socket to _host_

```sh
$ make SERVICE=mport MOUNTRO=y base
$ ./startnb.sh -n 1 -i mport-amd64.img 
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
$ make live # or make ARCH=evbarm-aarch64 live
$ ./startnb.sh -f etc/live.conf
```
This will fetch a directly bootable kernel and a _NetBSD_ "live", ready-to-use, disk image. Login with `root` and no password. To extend the size of the image to 4 more GB, simply do:

```sh
$ dd if=/dev/zero bs=1M count=4000 >> NetBSD-amd64-live.img
```
And reboot.

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
