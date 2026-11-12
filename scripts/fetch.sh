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
	curl ${CURL_FLAGS} -L -s "$fetchurl" | grep -oE "\"${matchfile}-[^\"]*(xz|gz)" | \
		while read f; do
			f=${f#\"}
			# mimic NetBSD's ftp parameters
			destfile=${f%-*}.${f##*.}
			# -f: HTTP errors must fail the fetch, not write
			# the error page into the output file; downloads
			# land in a .tmp.$$ file that is only published
			# by mv on success, so a failed fetch never
			# leaves a partial or stale file behind
			if [ "$flag" = "-o" ]; then
				curl ${CURL_FLAGS} -L -sf \
					-o "${dldir}/${destfile}.tmp.$$" \
					${fetchurl}/${f}
				rc=$?
				if [ $rc -eq 0 ]; then
					mv -f "${dldir}/${destfile}.tmp.$$" \
						${dldir}/${destfile}
				else
					rm -f "${dldir}/${destfile}.tmp.$$"
				fi
				exit $rc
			fi
			curl ${CURL_FLAGS} -L -sf -I ${fetchurl}/${f}
			exit $?
		done
	;;
*)
	if [ "$flag" = "-o" ]; then
		curl ${CURL_FLAGS} -L -sf -o "$outfile.tmp.$$" $fullurl
		rc=$?
		if [ $rc -eq 0 ]; then
			mv -f "$outfile.tmp.$$" $outfile
		else
			rm -f "$outfile.tmp.$$"
		fi
		exit $rc
	fi
	curl ${CURL_FLAGS} -L -sf -I $fullurl
	;;
esac
