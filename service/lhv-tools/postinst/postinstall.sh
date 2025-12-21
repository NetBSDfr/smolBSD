#!/bin/sh

export TERM="vt100"
. /etc/include/choupi
wwwroot="var/www"
toolsdir="../tmp/lhv-tools"


echo "${INFO} \"LHV tools\" prerequisites installation ..."
if [ -d ${toolsdir} ]; then rm -fr ${toolsdir}; fi
mkdir ${toolsdir}

#link="https://lehollandaisvolant.net/tout/tools/tools.tar.7z"
link="http://192.168.1.17:8000/tools.tar.7z"
${FETCH} -o ${toolsdir}/$(basename ${link}) ${link} 
if [ $? -ne 0 ]; then
	echo -e "${ERROR} \"LHV tools\" download failed.\nExit."
	. etc/include/shutdown
fi

# We can't use pipe like "curl -o- http://... | 7.z x ..." with 7z files. This file
# format can not be streamed, even with "-si" option. Have to use multiple steps.
# See https://7-zip.opensource.jp/chm/cmdline/switches/stdin.htm.
# 
# The archive will no longer be useful after unzipping and unarchiving, so,
# to avoid space disc consumption, download and decompression are made in the
# tmp/ directory of smolBSD, on the host file system.

echo -n "${ARROW} un-7zipping |"
# Unlike the "tar" command, "7z" is not necessarily installed everywhere. So it's
# installed on the microvm with "ADDPKGS" in options.mk and used here.
usr/pkg/bin/7z e -o${toolsdir} ${toolsdir}/$(basename ${link}) 2>&1 | awk '{printf "*"; fflush()}'
if [ $? -eq 0 ]; then
	echo "| done"
else
	echo -e "| ${ERROR} failed.\nExit"
	. etc/include/shutdown
fi

echo -n "${ARROW} un-taring |"
tar -xvf ${toolsdir}/$(basename ${link%.7z}) --strip-components=1 -C ${wwwroot} 2>&1 | awk '{printf "*"; fflush()}'
if [ $? -eq 0 ]; then
	echo "| done"
else
	echo -e "| ${ERROR} failed.\nExit"
	. etc/include/shutdown
fi

# Cleanup.
if [ -d ${toolsdir} ]; then rm -fr ${toolsdir}; fi

echo "${STAR} Enjoy !"
