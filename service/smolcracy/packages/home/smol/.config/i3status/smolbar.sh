#!/bin/sh
# smolcracy status bar: speaks the i3bar protocol directly so the widget
# set is not limited by what i3status understands about NetBSD.
# One loop tick = one `vmstat 1 2` sample (~1s) which doubles as the
# update timer: clock, load, cpu, memory and disk all refresh live.
NB='&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;&#160;'
( printf '{"version":1}\n[\n' )
while :; do
	CPUID=$(vmstat 1 2 | tail -1 | awk '{print $NF}')
	CPU=$((100 - ${CPUID:-0}))
	MEM=$(vmstat -s | awk '/pages active/{a=$1} /pages inactive/{i=$1} /pages wired/{w=$1} /pages managed/{t=$1} END{if(t)printf "%d",(a+i+w)*100/t}')
	LOAD=$(sysctl -n vm.loadavg | awk '{printf "%.1f", $1}')
	DISK=$(df -m / | tail -1 | awk '{printf "%.1f MiB", $4}')
	( printf '[{"markup":"pango","full_text":" %s"},{"full_text":" %s"},{"full_text":" %s%%"},{"full_text":" %s%%"},{"markup":"pango","full_text":" %s&#160;"}],\n' \
		"$(date '+%a %d %b  %H:%M')$NB" "$LOAD" "$CPU" "${MEM:-0}" "$DISK" )
done
