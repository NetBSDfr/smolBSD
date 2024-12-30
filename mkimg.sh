#!/bin/sh

progname=${0##*/}

usage()
{
	cat 1>&2 << _USAGE_
Usage: $progname [-s service] [-m megabytes] [-i image] [-x set]
       [-k kernel] [-o]
	Create a root image
	-s service	service name, default "rescue"
	-r rootdir	hand crafted root directory to use
	-m megabytes	image size in megabytes, default 10
	-i image	image name, default rescue-[arch].img
	-x sets		list of NetBSD sets, default rescue.tgz
	-k kernel	kernel to copy in the image
	-o		read-only root filesystem
_USAGE_
	exit 1
}

options="s:m:i:r:x:k:oh"

while getopts "$options" opt
do
	case $opt in
	s) svc="$OPTARG";;
	m) megs="$OPTARG";;
	i) img="$OPTARG";;
	r) rootdir="$OPTARG";;
	x) sets="$OPTARG";;
	k) kernel="$OPTARG";;
	o) rofs=y;;
	h) usage;;
	*) usage;;
	esac
done

arch=${ARCH:-"amd64"}

svc=${svc:-"rescue"}
megs=${megs:-"20"}
img=${img:-"rescue-${arch}.img"}
sets=${sets:-"rescue.tar.xz"}

[ ! -f service/${svc}/etc/rc ] && \
	echo "no service/${svc}/etc/rc available" && exit 1

OS=$(uname -s)

case $OS in
NetBSD)
	is_netbsd=1;;
Linux)
	is_linux=1;;
Darwin)
	# might be supported in the future
	is_darwin=1;;
OpenBSD)
	is_openbsd=1;;
*)
	is_unknown=1;
esac

[ -n "$is_darwin" -o -n "$is_unknown" ] && \
	echo "${progname}: OS is not supported" && exit 1

[ -n "$is_linux" ] && u=M || u=m

dd if=/dev/zero of=./${img} bs=1${u} count=${megs}

mkdir -p mnt
mnt=$(pwd)/mnt

if [ -n "$is_linux" ]; then
	mke2fs -O none $img
	[ -f /in_gh ] && \
		fuse-ext2 $img $mnt -o rw,force || \
		mount -o loop $img $mnt
	mountfs="ext2fs"
else # NetBSD (and probably OpenBSD)
	vnd=$(vndconfig -l|grep -m1 'not'|cut -f1 -d:)
	vndconfig $vnd $img
	newfs /dev/${vnd}a
	mount /dev/${vnd}a $mnt
	mountfs="ffs"
fi

# $rootdir can be relative, don't cd mnt yet
for d in sbin bin dev etc/include
do
	mkdir -p ${mnt}/$d
done
# root fs built by sailor or hand made
if [ -n "$rootdir" ]; then
	tar cfp - -C "$rootdir" . | tar xfp - -C $mnt
# use a set and customization in services/
else
	for s in ${sets}
	do
		tar xfp sets/${arch}/${s} -C ${mnt}/ || exit 1
	done

fi

cp -f service/${svc}/etc/* ${mnt}/etc/
cp -f service/common/* ${mnt}/etc/include/

[ -n "$rofs" ] && mountopt="ro" || mountopt="rw"
echo "ROOT.a / $mountfs $mountopt 1 1" > ${mnt}/etc/fstab

[ -n "$kernel" ] && cp -f $kernel ${mnt}/

cd $mnt

if [ "$svc" = "rescue" ]; then
	for b in init mount_ext2fs
	do
		ln -s /rescue/$b sbin/
	done
	ln -s /rescue/sh bin/
fi


# warning, postinst operations are done on the builder

[ -d ../service/${svc}/postinst ] && \
	for x in ../service/${svc}/postinst/*.sh
	do
		# if SVCIMG variable exists, only process its script
		if [ -n "$SVCIMG" ]; then
			[ "${x##*/}" != "${SVCIMG}.sh" ] && continue
			echo "SVCIMG=$SVCIMG" > etc/svc
		fi
		sh $x
	done

# newer NetBSD versions use tmpfs for /dev, sailor copies MAKEDEV from /dev
# backup MAKEDEV so imgbuilder rc can copy it
#cp /dev/MAKEDEV etc/
# unionfs with ext2 leads to i/o error
[ -z "$is_netbsd" ] && sed -i 's/-o union//g' dev/MAKEDEV

cd ..

umount $mnt

[ -z "$is_linux" ] && vndconfig -u $vnd

exit 0
