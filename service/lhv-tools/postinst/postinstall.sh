#!/bin/sh

. /etc/include/choupi

echo "${ARROW} \"LHV tools\" prerequisites installation ..."
wwwroot="var/www"
#link="https://lehollandaisvolant.net/tout/tools/tools.tar.7z"
link="http://192.168.1.87:40080/tools.tar.7z"
${FETCH} -o $(basename ${link}) ${link} 

if [ $? -ne 0 ]; then
	echo -e "${ERROR} \"LHV tools\" download failed.\nExit."
	. etc/include/shutdown
fi

echo "${ARROW} un-7zipping"
usr/pkg/bin/7z e -o${wwwroot} $(basename ${link}) >dev/null 2>&1

echo "${ARROW} un-taring"
tar xvf ${wwwroot}/$(basename ${link%.7z}) -C ${wwwroot} >dev/null 2>&1
rm -f ${wwwroot}/$(basename ${link%.7z})

echo "${STAR} Enjoy !"
