# smolcracy session body — runs as smol with DISPLAY/XAUTHORITY
# inherited from /etc/session.sh (su -m).  su's login class replaces
# PATH/HOME with the login defaults, so pin everything the desktop
# needs ourselves — X11R7/bin is NOT in the inherited PATH, which
# silently turned xrdb (and friends) into "command not found".
PATH=/usr/X11R7/bin:/usr/pkg/bin:/bin:/usr/bin:/usr/sbin:/sbin:/usr/pkg/sbin
export PATH
HOME=/home/smol
export HOME
SHELL=/usr/pkg/bin/bash
export SHELL
# AccelMethod "none" (no glamor) means no DRI3: Mesa clients run in
# software.  llvmpipe's AVX2 JIT aborts on this host CPU (LLVM 13
# machine-model bug), so use the JIT-free softpipe backend instead.
GALLIUM_DRIVER=softpipe
export GALLIUM_DRIVER
# never blank: DPMS-off over virtio-gpu shows QEMU's "Display output
# is not active" placeholder instead of the desktop (guest stays fine!)
( sleep 2; xset s off -dpms; xset dpms 0 0 0 ) >/dev/null 2>&1 &
FONTCONFIG_PATH=/usr/X11R7/etc/fonts
export FONTCONFIG_PATH
LANG=C.UTF-8	# btop refuses to start without a UTF-8 locale
export LANG

# session bus for dunst (notify-send) and friends
eval $(dbus-launch --sh-syntax)

# X resources (plain urxvt, no daemon, so every window picks up the
# database fresh).  Xorg drops RESOURCE_MANAGER writes for the first
# tens of seconds of its life, so hammer in the background until one
# sticks; the i3 terminal keys merge too, so the first window lands
# colored once writes work at all.
( i=0
  while [ $i -lt 60 ]; do
	i=$((i+1))
	xrdb -merge $HOME/.Xresources 2>>/tmp/xrdb.log
	# grep for a real entry: a failed xrdb prints its error to stdout,
	# which a plain wc -l would count as "entries present"
	[ "$(xrdb -query 2>/dev/null | grep -c URxvt)" -gt 0 ] && break
	sleep 2
  done
  echo "smolcracy: xrdb entries=$(xrdb -query 2>/dev/null | grep -c URxvt) tries=$i" \
	>>/tmp/xrdb.log ) &

mkdir -p ~/Pictures

# NetBSD console-derived keymap gets replaced seconds later by Xorg's own
# keyboard-device init (same late-hitting AIP window that drops xrdb
# writes), so a one-shot xmodmap at session start loses: PC keyboards
# send keycodes 133/134 for Super and NetBSD only maps legacy 115/116.
# Hammer until keycode 133 reads back Super_L five times in a row -- the
# reset can land over half a minute into a slow boot.
( i=0 ok=0
  while [ $i -lt 90 ]; do
	i=$((i+1))
	xmodmap -e "remove mod4 = Super_L Super_R" \
		-e "keycode 133 = Super_L NoSymbol Super_L" \
		-e "keycode 134 = Super_R NoSymbol Super_R" \
		-e "add mod4 = Super_L Super_R" 2>/dev/null
	if xmodmap -pke 2>/dev/null | grep -q '^keycode  *133 = Super_L'; then
		ok=$((ok+1)); [ $ok -ge 5 ] && break
	else	ok=0
	fi
	sleep 1
  done ) &
i=0
until i3 >>/tmp/i3.log 2>&1; do
	i=$((i+1))
	[ $i -ge 3 ] && break
	sleep 1
done
kill $DBUS_SESSION_BUS_PID 2>/dev/null
