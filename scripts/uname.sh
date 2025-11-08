#!/bin/sh

[ $# -lt 1 ] && exit 1

arg=$1

# Normalize architecture name
unamesh() {
	[ -n "$ARCH" ] || ARCH=$(uname -m 2>/dev/null || echo unknown)

	case $ARCH in
		x86_64|amd64)
			arch="amd64"
			machine="x86_64"
			;;
		i386|i486|i586|i686)
			arch="i386"
			machine="i386"
			;;
		*aarch64*|arm64|armv8*)
			arch="evbarm-aarch64"
			machine="aarch64"
			;;
		*)
			arch="$ARCH"
			machine="$ARCH"
			;;
	esac

	case $arg in
	-m)
		echo $arch
		;;
	-p)
		echo $machine
		;;
	*)
		echo "unkown flag"
		;;
	esac
}

[ "${0##*/}" = "uname.sh" ] && unamesh $arg || exit 1

exit 0
