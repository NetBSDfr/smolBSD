#!/bin/sh

flag=$1
if [ "$flag" = "-o" ]; then
	outfile=$2
	fullurl=$3
else
	fullurl=$2
fi

case $fullurl in
*\**)
	dldir=${outfile%/*} # pkgs/amd64/pkgin.tgz
	fetchurl=${fullurl%/*} 
	matchfile=${fullurl##*/}
	matchfile=${matchfile%\*}
	curl -L -s "$fetchurl" | grep -oE "\"${matchfile}-[^\"]*(xz|gz)" | \
		while read f; do
			f=${f#\"}
			# mimic NetBSD's ftp parameters
			destfile=${f%-*}.${f##*.}
			[ "$flag" = "-o" ] && curlaction="-o ${dldir}/${destfile}" || \
				curlaction="-I"
			curl -L -s ${curlaction} ${fetchurl}/${f}
			exit 0
		done
	;;
*)
	[ "$flag" = "-o" ] && curlaction="-o $outfile" || curlaction="-I"
	curl -L -s $curlaction $fullurl
	;;
esac
