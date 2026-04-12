#!/bin/sh

OS=$(uname -s|tr 'A-Z' 'a-z')

case $OS in
linux|darwin|freebsd) ;;
*)
	echo "unsupported platform"
	exit 1
	;;
esac

ARCH=$(uname -m | sed -e 's/x86_64/amd64/g;s/aarch64/arm64/')

PATH=${PATH}:bin

install_oras()
{
	command -v oras >/dev/null && return
	version=$(curl -s https://api.github.com/repos/oras-project/oras/releases/latest | jq -r '.tag_name')
	curl -fsSL "https://github.com/oras-project/oras/releases/download/${version}/oras_${version#v}_${OS}_${ARCH}.tar.gz" | \
		tar zxf - -C bin oras
}

pulsh_usage()
{
	if [ $# -lt 2 ]; then
		echo "usage: $1 <image>"
		exit 1
	fi
}

SMOLREPO=${SMOLREPO:-ghcr.io/netbsdfr/smolbsd}

case "$1" in
pull)
	pulsh_usage $@
	install_oras
	oras pull ${SMOLREPO}/$2
	;;
push)
	pulsh_usage $@
	install_oras
	ocimg=${2#*/}
	[ "$ocimg" = "$2" ] && imgpath="images" || imgpath="${2%/*}"
	ocimg=${ocimg%.img}
	oras push ${SMOLREPO}/${ocimg} \
		--artifact-type application/vnd.smolbsd.image \
		"${imgpath}/${ocimg}.img":application/x-raw-disk-image
	;;
images)
	cols=$(tput cols 2>/dev/null) || cols=80
	colsiz=$((cols / 4))
	namesiz=$((colsiz * 2))
	colsiz=$((colsiz / 2))
	fmt="%-${namesiz}s %-${colsiz}s %${colsiz}s %${colsiz}s\n"
	printf "\033[1m${fmt}\033[0m" IMAGE SIZE CREATED SIG
	for img in images/*.img
	do
		ctime=
		[ -f "$img" ] || continue
		base="${img##*/}"
		base="${base%.img}"
		size=$(du -sh $img|cut -f1)
		# stat(1) is not portable *at all*
		# "smolsig:01/01/1970|uuid"
		smolsig=$(tail -c 56 ${img}|grep -o 'smolsig:.*' 2>/dev/null)
		smolsig=${smolsig#smolsig:}
		[ -n "$smolsig" ] && ctime=${smolsig%|*}
		[ -z "$ctime" ] && ctime='01/01/1970'
		sigmatch=NOK
		sigfile="${img%.img}.sig"
		if [ -f "${sigfile}" ]; then
			rawsig="${smolsig#*|}"
			imgsig="$(tail -c 37 ${sigfile})"
			[ "$imgsig" = "$rawsig" ] && sigmatch=OK
		else
			# image has a signature but no sigfile, most
			# likely a downloaded image
			if [ -n "$smolsig" ]; then
				echo "smolsig:${ctime}:${smolsig#*|}" > \
					"$sigfile"
				sigmatch=OK
			fi
		fi
		printf "$fmt" "$base" "$size" "$ctime" "$sigmatch"
	done
	;;
*)
	echo "Unknown command: $1"
	exit 1
	;;
esac
