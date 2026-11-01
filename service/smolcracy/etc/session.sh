#!/bin/sh
# smolcracy-session.sh — GLX-accelerated Xorg (virtio-gpu/virgl) +
# Omarchy-style i3 desktop running as user smol (passwordless doas
# to root).  Distilled from service/xbase etc/session.sh; must run
# as root from /etc/rc.

PATH=$PATH:/usr/X11R7/bin:/usr/pkg/bin
export PATH
export DISPLAY=:1
export LANG=C.UTF-8		# btop refuses to start without a UTF-8 locale
export VIRGL_3D_THROTTLE=0	# else the mesa virgl swap throttle pins the desktop at ~5fps
export FONTCONFIG_PATH=/usr/X11R7/etc/fonts	# pkgsrc fontconfig has no compiled-in config path
export CONSOLEDEVICE=/dev/ttyE0

# Drop privileges to smol without PAM (base PAM is broken in Oct-2026
# builds: pam_start fails for su, login, and sudo).  doas (pkgsrc) and
# daemon(8) use setusercontext(); plain exec as root is the last resort.
if command -v doas >/dev/null 2>&1; then SMOLL="doas -u smol"
elif command -v daemon >/dev/null 2>&1; then SMOLL="daemon -u smol"
else SMOLL=""; fi


# session exit ends in reboot, not halt: startnb -X adds -no-reboot,
# so reboot makes QEMU exit and the window disappears, while a halt
# leaves it stuck on screen.  ro-remount the rw root first; if
# reboot -q ever returns, /etc/rc falls back to halt as before.
power_off() {
	sync; sync
	mount -u -o ro / 2>/dev/null
	reboot -q
}

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

mount -t tmpfs -o -s64m tmpfs /tmp 2>/dev/null

# PAM (login/su) is broken in the Oct-2026 base for reasons still
# unclear upstream; daemon -u (setusercontext, no PAM) runs the session,
# and sh the console,
# but keep /var/run/log present for anything that still calls pam_start
mkdir -p /var/run
[ -e /var/run/log ] || : >/var/run/log

# the desktop runs as smol: give the user the DRM nodes (no udev on
# the guest) and an X cookie owned by smol that Xorg seeds itself
chmod 666 /dev/dri/* 2>/dev/null
XAUTHORITY=/home/smol/.Xauthority
export XAUTHORITY
touch $XAUTHORITY 2>/dev/null
chown smol $XAUTHORITY 2>/dev/null

xtry() {
	echo "SMOLCRACY: trying Xorg $*"
	Xorg "$@" -config /etc/xorg.conf -nolisten tcp >/tmp/Xorg.log 2>&1 &
	XPID=$!
	i=0
	while [ $i -lt 20 ]; do
		i=$((i+1))
		sleep 1
		[ -e /tmp/.X11-unix/X1 ] && break
	done
	if [ -e /tmp/.X11-unix/X1 ]; then
		echo "SMOLCRACY: Xorg up ($*) after ${i}s"
		return 0
	fi
	echo "SMOLCRACY: Xorg FAILED ($*)"
	kill $XPID 2>/dev/null
	wait $XPID 2>/dev/null
	return 1
}

if xtry :1 || xtry :1 -vtdev /dev/ttyE0 || xtry :1 vt2 ||
	{ unset CONSOLEDEVICE; xtry :1; } ||
	{ export CONSOLEDEVICE=/dev/ttyE0; xtry :1 -novtswitch; }; then
	:
else
	echo "SMOLCRACY: all Xorg attempts failed, tail of /tmp/Xorg.log:"
	tail -25 /tmp/Xorg.log
	power_off
	exit 1
fi

# serial console shell (autologin root).  getty -a hides PAM/utmpx
# failures (§20.3 sharp edge), so use an explicit login loop: any
# failure reason is printed to serial and retried.
pwd_mkdb -p /etc/master.passwd >/dev/null 2>&1
echo "SMOLCRACY: starting console shell"
( while :; do env TERM=vt220 sh -i; sleep 1; done ) \
	</dev/console >/dev/console 2>&1 &

# GLX sanity as the session user: also proves /dev/dri perms for smol
# (timeout: glxinfo can wedge on a dead X)
timeout 10 $SMOLL env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY /usr/X11R7/bin/glxinfo 2>&1 |
	grep -E 'direct rendering|renderer string|version string' |
	sed 's/^/SMOLCRACY glx: /'

# the desktop: HOME pinned for the ~/.config lookups, env kept by
# su -m.  X resources load inside .xsession: early root-side xrdb
# attempts raced X startup and its log redirection starved the user
# merge, so root stays out of it entirely.  End the session when
# either side dies: user logout (i3 exit) or an Xorg crash.
echo "SMOLCRACY: starting i3 session as smol"
( $SMOLL env HOME=/home/smol DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY LANG=$LANG FONTCONFIG_PATH=$FONTCONFIG_PATH LD_LIBRARY_PATH=$LD_LIBRARY_PATH VIRGL_3D_THROTTLE=$VIRGL_3D_THROTTLE sh /home/smol/.xsession ) &
SPID=$!
wait $SPID
echo "SMOLCRACY: session ended"
tail -25 /tmp/i3.log 2>/dev/null | sed "s/^/SMOLCRACY i3: /"
tail -8 /tmp/xrdb.log 2>/dev/null | sed "s/^/SMOLCRACY xrdb: /"
kill $XPID 2>/dev/null
wait $XPID 2>/dev/null
power_off
