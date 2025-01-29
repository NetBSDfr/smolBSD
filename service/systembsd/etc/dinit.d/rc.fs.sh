#!/bin/sh

/etc/rc.d/mountcritlocal $1
/etc/rc.d/mountall $1

if [ "$1" = "stop" ]; then
	for fs in /dev/pts /dev
	do
		/sbin/umount -f $fs
	done
fi
