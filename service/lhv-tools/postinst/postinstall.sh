#!/bin/sh

. /etc/include/choupi
wwwroot="var/www"
toolsdir="../tmp/lhv-tools"

# To avoid "warning: TERM is not set" message and be able to vi files if needed.
echo 'export TERM="vt100"' > etc/profile

echo "${ARROW} php settings ..."
mkdir -p usr/pkg/etc/php/8.4/
cp usr/pkg/share/examples/php/8.4/php.ini-production usr/pkg/etc/php/8.4/php.ini
sed -i'' 's/;extension=curl/extension=curl/g' usr/pkg/etc/php/8.4/php.ini

# Some .php files are not interpeted by bozohttpd when they are called with
# 'foldername/' URL. The content of the file is sent as is to the browser.
# The .bzremap file acts as rewriting rules to force the call of the
# 'foldername/index.php' file presents into each problematic tool's folder.
echo "${ARROW} bozo settings for some .php files"
cat >${wwwroot}/.bzremap<<EOF
/browser/:/browser/index.php
/htmlol/:/htmlol/index.php
EOF

echo "${INFO} \"LHV tools\" prerequisites installation ..."
if [ -d ${toolsdir} ]; then rm -fr ${toolsdir}; fi
mkdir ${toolsdir}

link="https://lehollandaisvolant.net/tout/tools/tools.tar.7z"
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
tar -xvf ${toolsdir}/$(basename ${link%.7z}) -C ${wwwroot} 2>&1 | awk '{printf "*"; fflush()}'
if [ $? -eq 0 ]; then
	echo "| done"
else
	echo -e "| ${ERROR} failed.\nExit"
	. etc/include/shutdown
fi

echo "${ARROW} fix favicon"
# -k because no certificates stuff used by curl is installed.
${FETCH} -o ${wwwroot}/favicon.ico https://lehollandaisvolant.net/index/icons/favicon-32x32.png -k

echo "${ARROW} fix logo"
sed -i'' 's,/index/logo-no-border.png,0common/lhv-384x384.png,g' ${wwwroot}/index.php
sed -i'' 's,/index/logo-no-border.png,../0common/lhv-384x384.png,g' ${wwwroot}/*/index.php ${wwwroot}/cgu.php

echo "${ARROW} fix archive link"
sed -i'' 's,href="tools.tar.7z,href="https://lehollandaisvolant.net/tout/tools/tools.tar.7z,g' ${wwwroot}/cgu.php ${wwwroot}/index.php

echo "${ARROW} fix footer"
sed -i'' 's,</section>,</section>\n<footer id="footer"><a href="//lehollandaisvolant.net">by <em>Timo Van Neerden</em></a></footer>,g' ${wwwroot}/barcode/index.php
sed -i'' 's,<a href="/">by <em>Timo Van Neerden,<a href="//lehollandaisvolant.net">by <em>Timo Van Neerden,g' ${wwwroot}/*/index.php
sed -i'' 's,<a href="/">Timo Van Neerden,<a href="//lehollandaisvolant.net">Timo Van Neerden,g' ${wwwroot}/index.php ${wwwroot}/cgu.php


# Cleanup
if [ -d ${toolsdir} ]; then rm -fr ${toolsdir}; fi

echo "${STAR} Enjoy !"
