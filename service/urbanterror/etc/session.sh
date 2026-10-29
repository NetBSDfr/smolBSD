#!/bin/sh
# urbanterror-session.sh — bring up GLX-accelerated Xorg (virtio-gpu/virgl)
# and run Urban Terror (ioquake3 engine) directly on it: no window
# manager, windowed mode, and the VM halts when the game exits.
# Distilled from service/xbase session.sh; must run as root from /etc/rc.

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
	echo "UT: trying Xorg $*"
	Xorg "$@" -config /etc/xorg.conf -nolisten tcp >/tmp/Xorg.log 2>&1 &
	XPID=$!
	i=0
	while [ $i -lt 20 ]; do
		i=$((i+1))
		sleep 1
		[ -e /tmp/.X11-unix/X1 ] && break
	done
	if [ -e /tmp/.X11-unix/X1 ]; then
		echo "UT: Xorg up ($*) after ${i}s"
		return 0
	fi
	echo "UT: Xorg FAILED ($*)"
	kill $XPID 2>/dev/null
	wait $XPID 2>/dev/null
	return 1
}

if xtry :1 || xtry :1 -vtdev /dev/ttyE0 || xtry :1 vt2 ||
	{ unset CONSOLEDEVICE; xtry :1; } ||
	{ export CONSOLEDEVICE=/dev/ttyE0; xtry :1 -novtswitch; }; then
	:
else
	echo "UT: all Xorg attempts failed, tail of /tmp/Xorg.log:"
	tail -25 /tmp/Xorg.log
	exit 1	# /etc/rc falls through to shutdown -> VM halts
fi

# serial console shell (autologin root); login loop prints any failure
# reason to serial instead of dying silently like getty -a does
pwd_mkdb -p /etc/master.passwd >/dev/null 2>&1
echo "UT: starting console shell"
( while :; do env TERM=vt220 login -fp root; sleep 1; done ) \
	</dev/console >/dev/console 2>&1 &

# GLX sanity: log renderer to serial console (timeout: glxinfo can wedge
# on a dead X)
timeout 10 glxinfo 2>&1 |
	grep -E 'direct rendering|renderer string|version string' |
	sed 's/^/UT glx: /'

# Hide the X server root cursor (the hollow-X default): with in_nograb
# the game never grabs or blanks it and never defines its own, so the
# window inherits root's X_cursor.  xset has no "cursor none" on NetBSD;
# xsetroot -cursor does, but needs a bitmap with hotspot defines (a
# 2x2 all-zero one = invisible).  Verified on a live game: root cursor
# blanked, Urban Terror's own drawn cursor unaffected.
printf '#define b_width 2\n#define b_height 2\n#define b_x_hot 0\n#define b_y_hot 0\nstatic char b_bits[] = {\n  0x00, 0x00, 0x00, 0x00 };\n' > /tmp/blank.xbm
DISPLAY=:1 xsetroot -cursor /tmp/blank.xbm /tmp/blank.xbm

# Urban Terror: windowed X (r_mode -1, window sized to the guest screen),
# settings land in /root/.q3a; the serial shell stays usable for logs.
# in_raw 0: the engine's XInput2 raw path reads the virtio-tablet's
# absolute axes as relative deltas -> unusably fast + inverted pointer;
# core X events go through the ws driver's calibration instead.
# in_nograb 1: with an absolute pointing device the game's per-frame
# XWarpPointer-to-center fakes motion (~2x overspeed); without the grab
# the game derives deltas from the absolute position, like the desktop.
# Window == screen size so host pointer to guest cursor is 1:1.
# Game exit takes down Xorg and the session, so /etc/rc halts the VM.
echo "UT: launching urbanterror"
HOME=/root urbanterror +set r_fullscreen 0 +set in_raw 0 +set in_nograb 1 \
	+set r_mode -1 +set r_customwidth 1280 +set r_customheight 800 \
	>/tmp/urbanterror.log 2>&1
echo "UT: urbanterror exited:"
tail -40 /tmp/urbanterror.log | sed 's/^/UTlog: /'
kill $XPID 2>/dev/null
exit 0
