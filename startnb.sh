#!/bin/sh

usage()
{
	cat 1>&2 << _USAGE_
Usage:	${0##*/} -f conffile | -k kernel -i image [-c CPUs] [-m memory]
	[-a kernel parameters] [-r root disk] [-h drive2] [-p port]
	[-t tcp serial port] [-w path] [-x qemu extra args]
	[-N] [-b] [-n] [-s] [-d] [-v] [-u]

	Boot a microvm
	-f conffile	vm config file
	-k kernel	kernel to boot on
	-i image	image to use as root filesystem
	-I		load image as initrd
	-c cores	number of CPUs
	-m memory	memory in MB
	-a parameters	append kernel parameters
	-r root disk	root disk to boot on
	-l drive2	second drive to pass to image
	-t serial port	TCP serial port
	-n num sockets	number of VirtIO console socket
	-p ports	[tcp|udp]:[hostaddr]:hostport-[guestaddr]:guestport
	-w path		host path to share with guest (9p)
	-x arguments	extra qemu arguments
	-N		disable networking
	-b		bridge mode
	-s		don't lock image file
	-d		daemonize
	-v		verbose
	-u		non-colorful output
	-h		this help
_USAGE_
	# as per https://www.qemu.org/docs/master/system/invocation.html
	# hostfwd=[tcp|udp]:[hostaddr]:hostport-[guestaddr]:guestport
	exit 1
}

# Check if VirtualBox VM is running
if pgrep VirtualBoxVM >/dev/null 2>&1; then
	echo "Unable to start KVM: VirtualBox is running"
	exit 1
fi

options="f:k:a:p:i:Im:n:c:r:l:p:uw:x:t:hbdsv"

export CHOUPI=y

uuid="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c8)"

# and possibly override its values
while getopts "$options" opt
do
	case $opt in
	a) append="$OPTARG";;
	b) bridgenet=yes;;
	c) cores="$OPTARG";;
	d) DAEMON=yes;;
	# first load vm config file
	f)
		. $OPTARG
		# extract service from file name
		svc=${OPTARG%.conf}
		svc=${svc##*/}
		;;
	h) usage;;
	i) img="$OPTARG";;
	I) initrd="-initrd";;
	# and possibly override values
	k) kernel="$OPTARG";;
	l) drive2=$OPTARG;;
	m) mem="$OPTARG";;
	n) max_ports=$(($OPTARG + 1));;
	p) hostfwd=$OPTARG;;
	r) root="$OPTARG";;
	s) sharerw=yes;;
	t) serial_port=$OPTARG;;
	u) CHOUPI="";;
	v) VERBOSE=yes;;
	N) nonet=yes;;
	w) share=$OPTARG;;
	x) extra=$OPTARG;;
	*) usage;;
	esac
done

. service/common/choupi

# envvars override
kernel=${kernel:-$KERNEL}
img=${img:-$NBIMG}

# enable QEMU user network by default
[ -z "$nonet" ] && network="\
-device virtio-net-device,netdev=net-${uuid}0 \
-netdev user,id=net-${uuid}0,ipv6=off"

if [ -n "$hostfwd" ]; then
	network="${network},$(echo "$hostfwd"|sed -E 's/(udp|tcp)?::/hostfwd=\1::/g')"
	echo "${ARROW} port forward set: $hostfwd"
fi

[ -n "$bridgenet" ] && network="$network \
-device virtio-net-device,netdev=net-${uuid}1 \
-netdev type=tap,id=net-${uuid}1"

[ -n "$drive2" ] && drive2="\
-device virtio-blk-device,drive=hd-${uuid}1 \
-drive if=none,file=${drive2},format=raw,id=hd-${uuid}1"

[ -n "$share" ] && share="\
-fsdev local,path=${share},security_model=none,id=shar-${uuid}0 \
-device virtio-9p-device,fsdev=shar-${uuid}0,mount_tag=shar-${uuid}0"

[ -n "$sharerw" ] && sharerw=",share-rw=on"

OS=$(uname -s)
arch=$(scripts/uname.sh -m)
machine=$(scripts/uname.sh -p)

cputype="host"

case $OS in
NetBSD)
	accel="-accel nvmm,prefault=on"
	;;
Linux)
	accel="-accel kvm"
	;;
Darwin)
	accel="-accel hvf"
	# Mac M1, M2, M3, M4
	cputype="cortex-a710"
	;;
OpenBSD|FreeBSD)
	accel="-accel tcg" # unaccelerated
	cputype="qemu64"
	;;
*)
	echo "Unknown hypervisor, no acceleration"
esac

QEMU=${QEMU:-qemu-system-${machine}}
printf "${ARROW} using QEMU "
$QEMU --version|grep -oE 'version .*'

mem=${mem:-"256"}
cores=${cores:-"1"}
append=${append:-"-z"}

case $machine in
x86_64|i386)
	mflags="-M microvm,rtc=on,acpi=off,pic=off"
	cpuflags="-cpu ${cputype},+invtsc"
	root=${root:-"ld0a"}
	# stack smashing with version 9.0 and 9.1
	${QEMU} --version|grep -q -E '9\.[01]' && \
		extra="$extra -L bios -bios bios-microvm.bin"
	case $machine in
	i386)
		kernel=${kernel:-kernels/netbsd-SMOL386}
		;;
	x86_64)
		kernel=${kernel:-kernels/netbsd-SMOL}
		;;
	esac
	;;
aarch64)
	mflags="-M virt,highmem=off,gic-version=3"
	cpuflags="-cpu ${cputype}"
	root=${root:-"ld4a"}
	extra="$extra -device virtio-rng-pci"
	kernel=${kernel:-kernels/netbsd-GENERIC64.img}
	;;
*)
	echo "${WARN} Unknown architecture"
esac

echo "${ARROW} using kernel $kernel"

# use VirtIO console when available, if not, emulated ISA serial console
if nm $kernel 2>&1 | grep -q viocon_earlyinit; then
	console=viocon
	[ -z "$max_ports" ] && max_ports=1
	consdev="\
-chardev stdio,signal=off,mux=on,id=char0 \
-device virtio-serial-device,max_ports=${max_ports} \
-device virtconsole,chardev=char0,name=char0"
else
	consdev="-serial mon:stdio"
	console=com
fi
echo "${ARROW} using console: $console"

# conf file was given
[ -z "$img" ] && [ -n "$svc" ] && img=images/${svc}-${arch}.img

if [ -z "$img" ]; then
	printf "no 'image' defined\n\n" 1>&2
	usage
fi

if [ -z "${initrd}" ]; then
	echo "${ARROW} using disk image $img"
	img="-drive if=none,file=${img},format=raw,id=hd-${uuid}0 \
-device virtio-blk-device,drive=hd-${uuid}0${sharerw}"
	root="root=${root}"
else
	echo "${ARROW} loading $img as initrd"
	root=""
fi

# svc *must* be defined to be able to store qemu PID in a unique filename
if [ -z "$svc" ]; then
	svc=${uuid}
	echo "${ARROW} no service name, using UUID ($uuid)"
fi

d="-display none -pidfile qemu-${svc}.pid"

if [ -n "$DAEMON" ]; then
	# XXX: daemonize makes viocon crash
	console=com
	unset max_ports
	# a TCP port is specified
	if [ -n "${serial_port}" ]; then
		serial="-serial telnet:localhost:${serial_port},server,nowait"
		echo "${ARROW} using serial: localhost:${serial_port}"
	fi

	d="$d -daemonize $serial"
else
	# console output
	d="$d $consdev"
fi

if [ -n "$max_ports" ] && [ $max_ports -gt 1 ]; then
	for v in $(seq $((max_ports - 1)))
	do
		sockid="${uuid}-p${v}"
		sockname="sock-${sockid}"
		sockpath="s-${sockid}.sock"
		viosock="$viosock \
-chardev socket,path=${sockpath},server=on,wait=off,id=${sockname} \
-device virtconsole,chardev=${sockname},name=${sockname}"
		echo "${INFO} host socket ${v}: ${sockpath}"
	done
fi
# QMP is available
[ -n "${qmp_port}" ] && extra="$extra -qmp tcp:localhost:${qmp_port},server,wait=off"

cmd="${QEMU} -smp $cores \
	$accel $mflags -m $mem $cpuflags \
	-kernel $kernel $initrd ${img} \
	-append \"console=${console} ${root} ${append}\" \
	-global virtio-mmio.force-legacy=false ${share} \
	${drive2} ${network} ${d} ${viosock} ${extra}"

[ -n "$VERBOSE" ] && echo "$cmd" && exit

eval $cmd
