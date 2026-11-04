#!/bin/sh
# smolcracy app launcher - adi1090x type-4 style-1 (Super+space).
# rofi 2.0 ignores font: and configuration{} in -theme files, so all of
# that is passed on the command line here.
# Icons come from the bundled Icomoon-Feather.ttf (codepoints verified by
# rendering: search E9CC, terminal E9E9, folder E96C).  JBM lacks the
# U+F0xx fontawesome block, so these render via fontconfig fallback.
dir=$(dirname -- "$0")
ic_drun=$(printf '\356\247\214')	# U+E9CC feather search
ic_run=$(printf '\356\247\251')		# U+E9E9 feather terminal
ic_fb=$(printf '\356\245\254')		# U+E96C feather folder
exec rofi -show drun \
	-modi drun,run,filebrowser \
	-theme "$dir/drun.rasi" \
	-font "JetBrainsMono Nerd Font Mono 11" \
	-display-drun "$ic_drun" \
	-display-run "$ic_run" \
	-display-filebrowser "$ic_fb" \
	-drun-display-format "{name} [<span weight='light' size='small'><i>({generic})</i></span>]"
