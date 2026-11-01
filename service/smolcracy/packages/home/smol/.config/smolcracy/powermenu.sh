#!/bin/sh
# smolcracy system menu (Super+Escape), Omarchy power-menu slot
c=$(printf "Lock\nLogout\nReboot\nPower off\n" | rofi -dmenu -p system)
[ -z "$c" ] && exit 0
[ "$c" = "Lock" ] && exec i3lock -e -c 1e1e2e
[ "$c" = "Logout" ] && exec i3-msg exit
[ "$c" = "Reboot" ] && exec doas shutdown -r now
[ "$c" = "Power off" ] && exec doas shutdown -p now
