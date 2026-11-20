#!/bin/sh

mkdir -p usr/pkg/etc/pkgin
ARCHN=${ARCH#evbarm-}
PKGSITE="${PKGSITE:-https://pkg.smolbsd.org/pub/pkgsrc/packages/NetBSD/${ARCHN}/${PKGVERS}/All}"
printf '%s\n' "${PKGSITE}" "# fallback if ever needed: https://cdn.netbsd.org/pub/pkgsrc/packages/NetBSD/${ARCHN}/${PKGVERS}/All" > \
	usr/pkg/etc/pkgin/repositories.conf

touch BUILDIMG
mkdir ${DRIVE2#/}
# mkimg searches for ../service
ln -sf /mnt/service .
