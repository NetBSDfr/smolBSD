#!/bin/sh
# xbase-session.sh — bring up GLX-accelerated Xorg (virtio-gpu/virgl)
# plus fluxbox and a serial-console shell.  Distilled from the proven
# service/vioglx etc/rc; must run as root from /etc/rc.

PATH=$PATH:/usr/X11R7/bin:/usr/pkg/bin
export PATH
export DISPLAY=:1
export VIRGL_3D_THROTTLE=0	# else the mesa virgl swap throttle pins the desktop at ~5fps
export CONSOLEDEVICE=/dev/ttyE0

# wscons + DRM device nodes
cd /dev
sh MAKEDEV wscons 2>/dev/null
sh MAKEDEV drm 2>/dev/null
if [ ! -c /dev/ttyE0 ]; then
	mkdir -p /dev/wscons
	i=0
	while [ $i -lt 4 ]; do
		mknod /dev/ttyE$i c 172 $i
		mknod /dev/wscons/wsdisplay$i c 181 $i 2>/dev/null
		mknod /dev/wscons/wskbd$i c 182 $i 2>/dev/null
		i=$((i+1))
	done
fi
cd /

mount -t tmpfs -o -s64M tmpfs /tmp 2>/dev/null

xtry() {
	echo "XBASE: trying Xorg $*"
	Xorg "$@" -config /etc/xorg.conf -nolisten tcp >/tmp/Xorg.log 2>&1 &
	XPID=$!
	i=0
	while [ $i -lt 20 ]; do
		i=$((i+1))
		sleep 1
		[ -e /tmp/.X11-unix/X1 ] && break
	done
	if [ -e /tmp/.X11-unix/X1 ]; then
		echo "XBASE: Xorg up ($*) after ${i}s"
		return 0
	fi
	echo "XBASE: Xorg FAILED ($*)"
	kill $XPID 2>/dev/null
	wait $XPID 2>/dev/null
	return 1
}

if xtry :1 || xtry :1 -vtdev /dev/ttyE0 || xtry :1 vt2 ||
	{ unset CONSOLEDEVICE; xtry :1; } ||
	{ export CONSOLEDEVICE=/dev/ttyE0; xtry :1 -novtswitch; }; then
	:
else
	echo "XBASE: all Xorg attempts failed, tail of /tmp/Xorg.log:"
	tail -25 /tmp/Xorg.log
	exit 1	# /etc/rc falls through to shutdown -> VM halts
fi

# serial console shell (autologin root).  getty -a hides PAM/utmpx
# failures (§20.3 sharp edge), so use an explicit login loop: any
# failure reason is printed to serial and retried.
pwd_mkdb -p /etc/master.passwd >/dev/null 2>&1
echo "XBASE: starting console shell"
( while :; do env TERM=vt220 login -fp root; sleep 1; done ) \
	</dev/console >/dev/console 2>&1 &

# GLX sanity: log renderer to serial console (timeout: glxinfo can wedge
# on a dead X)
timeout 10 glxinfo 2>&1 |
	grep -E 'direct rendering|renderer string|version string' |
	sed 's/^/XBASE glx: /'

# window manager: fluxbox.  It falls back to packaged defaults when
# ~/.fluxbox is absent, but its default rootCommand (fbsetbg -l) needs
# fbsetroot which is not in the xbase set: paint a solid background
# with xsetroot instead, or the root window keeps the gray X stipple.
# HOME may be unset when started from /etc/rc, pin it for the
# ~/.fluxbox lookup, and its rootCommand (fbsetbg -l -> generic xsetbg
# fallback) paints the root dark gray, so repaint black once it has run.
HOME=/root fluxbox >/tmp/fluxbox.log 2>&1 &
sleep 2
xsetroot -solid black

# block on Xorg: when it exits, /etc/rc runs shutdown and the VM halts
wait $XPID
echo "XBASE: Xorg exited"
