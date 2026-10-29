#!/bin/sh

set -e

if [ ! -f /BUILDIMG ]; then
	echo "❌ NOT IN BUILDER IMAGE! EXITING"
	exit 1
fi
. ../service/common/funcs

rootdir=$(pwd) # postinst is ran from fake root
cat >etc/profile<<_PROFILE
PATH=$PATH:/sbin:/usr/sbin:/usr/pkg/bin:/usr/pkg/sbin
export PATH
_PROFILE
cp /etc/resolv.conf etc/
mkdir -p usr/pkg/etc/pkgin
# evbarm-aarch64 repo name is aarch64
ARCH=${ARCH#evbarm-}
echo "https://cdn.netbsd.org/pub/pkgsrc/packages/NetBSD/${ARCH}/${PKGVERS}/All" 	>usr/pkg/etc/pkgin/repositories.conf
rsynclite /etc/openssl/ ${rootdir}/etc/openssl
