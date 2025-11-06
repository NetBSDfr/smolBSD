# VM batch creation and bench

You need [smolBSD](https://github.com/NetBSDfr/smolBSD) to test the following

## Read-only `bozohttpd` web server image

* Create the base image

```sh
$ make MOUNTRO=y SERVICE=bozohttpd build
```
* Create a config file template

```sh
$ cat etc/bozohttpd.conf
# mandatory
img=bozohttpd-amd64.img
# mandatory
kernel=netbsd-SMOL # https://smolbsd.org/assets/netbsd-SMOL
# optional
mem=128m
# optional
cores=1
# optional port forward
hostfwd=::8180-:80
# optional extra parameters
extra=""
# don't lock the disk image
sharerw="y"
```

* Try it

```sh
$ ./startnb.sh -f etc/bozohttpd.conf
```
exit `qemu` with `Ctrl-a x`

## Example shell script, parallel run

Just play with the `num` variable

```sh
#!/bin/sh

vmname=bozohttpd
num=9

for i in $(seq 1 $num)
do
        sed "s/8180/818$i/" etc/${vmname}.conf > etc/${vmname}${i}.conf
done

for f in etc/${vmname}[0-9]*.conf; do
  . $f
  echo "starting $vm"
  ./startnb.sh -f $f -d &
done

for i in $(seq 1 $num)
do
        while ! curl -s -I --max-time 0.01 localhost:818${i}
        do
                true
        done
done

for i in $(seq 1 $num); do curl -I http://localhost:818${i}; done

for i in $(seq 1 $num); do kill $(cat qemu-${vmname}${i}.pid); done

rm -f etc/${vmname}[0-9]*.conf
```
