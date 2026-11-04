#!/bin/sh
# smolcracy system menu (Super+Escape), Omarchy power-menu slot.
# Look: adi1090x rofi powermenu type-2 style 9 (icon tiles, blue
# selection). Icons are Material Design codepoints carried by the
# JetBrainsMono Nerd Font, so entries are glyphs mapped to actions.
dir=$(dirname -- "$0")
ic_lock=󰌾
ic_logout=󰍃
ic_reboot=󰜈
ic_power=󰐤
c=$(printf '%s\n%s\n%s\n%s\n' "$ic_lock" "$ic_logout" "$ic_reboot" "$ic_power" |
	rofi -dmenu -font "JetBrainsMono Nerd Font Mono 44" -p "" -theme "$dir/powermenu.rasi")
[ -z "$c" ] && exit 0
case "$c" in
"$ic_lock")   exec i3lock -e -c 1e1e2e ;;
"$ic_logout") exec i3-msg exit ;;
"$ic_reboot") exec doas shutdown -r now ;;
"$ic_power")  exec doas shutdown -p now ;;
esac
