#!/bin/sh
# smolcracy status bar: speaks the i3bar protocol directly so the widget
# set is not limited by what i3status understands about NetBSD.
# One loop tick = one `vmstat 1 2` sample (~1s) which doubles as the
# update timer: clock, load, cpu, memory and disk all refresh live.
# The clock rides in the first block and i3bar right-packs blocks
# (this i3bar ignores the "align" property), so it is centered with
# trailing &#160; spacers sized from the live bar width: bar font
# ~8.2 px/char at the pinned Xft.dpi 96, status group ~222 px ->
# NB = barW*100/1616 - 38 (1280 -> 41, 1920 -> 80; measured within
# 8px of center at 1024/1280/1920).  X mode changes are picked up on
# the next tick.
BARW=$(xdpyinfo 2>/dev/null | awk '/dimensions/{print $2+0}' | sed -n 1p)
[ -n "$BARW" ] || BARW=1280
NB=""
mknb() {
	NB=""
	i=0
	while [ $i -lt $1 ]; do NB="$NB&#160;"; i=$((i+1)); done
}
N=$(( BARW * 100 / 1616 - 38 ))
[ $N -lt 0 ] && N=0
mknb $N
( printf '{"version":1}\n[\n' )
while :; do
	CPUID=$(vmstat 1 2 | tail -1 | awk '{print $NF}')
	CPU=$((100 - ${CPUID:-0}))
	MEM=$(vmstat -s | awk '/pages active/{a=$1} /pages inactive/{i=$1} /pages wired/{w=$1} /pages managed/{t=$1} END{if(t)printf "%d",(a+i+w)*100/t}')
	LOAD=$(sysctl -n vm.loadavg | awk '{printf "%.1f", $1}')
	DISK=$(df -m / | tail -1 | awk '{printf "%.1f MiB", $4}')
	B=$(xdpyinfo 2>/dev/null | awk '/dimensions/{print $2+0}' | sed -n 1p)
	if [ -n "$B" ] && [ "$B" != "$BARW" ]; then
		BARW=$B
		N=$(( BARW * 100 / 1616 - 38 ))
		[ $N -lt 0 ] && N=0
		mknb $N
	fi
	( printf '[{"markup":"pango","full_text":" %s"},{"full_text":" %s"},{"full_text":" %s%%"},{"full_text":" %s%%"},{"markup":"pango","full_text":" %s&#160;"}],\n' \
		"$(date '+%a %d %b  %H:%M')$NB" "$LOAD" "$CPU" "${MEM:-0}" "$DISK" )
done
