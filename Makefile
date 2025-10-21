.-include "service/${SERVICE}/options.mk"

VERS?=		11
PKGVERS?=	11.0_2025Q3
UNAME_M!=	uname -m
UNAME_S!=	uname -s
# for an obscure reason, packages path use uname -m...
DIST?=		https://nycdn.netbsd.org/pub/NetBSD-daily/netbsd-${VERS}/latest/${ARCH}/binary
.if !defined(ARCH)
.  if ${UNAME_M} == "x86_64" || ${UNAME_M} == "amd64"
ARCH=		amd64
.  elif ${UNAME_M} == "aarch64" || ${UNAME_M} == "arm64"
ARCH=		evbarm-aarch64
.  else
ARCH=		${UNAME_M}
.  endif
.endif
PKGSITE?=	https://cdn.netbsd.org/pub/pkgsrc/packages/NetBSD/${UNAME_M}/${PKGVERS}/All
PKGS?=		packages
KDIST=		${DIST}
WHOAMI!=	whoami
USER!= 		id -un
GROUP!= 	id -gn
BUILDIMG=	build-${ARCH}.img
BUILDIMGURL=	https://github.com/NetBSDfr/smolBSD/releases/download/latest/${BUILDIMG}

SERVICE?=	${.TARGET}
# guest root filesystem will be read-only
.if defined(MOUNTRO) && ${MOUNTRO} == "y"
EXTRAS+=	-o
.endif

ENVVARS=	SERVICE=${SERVICE} ARCH=${ARCH} PKGVERS=${PKGVERS} MOUNTRO=${MOUNTRO}
.if ${WHOAMI} != "root"
# macOS doesn't need sudo anymore (uses staging approach)
.  if ${UNAME_S} == "Darwin"
SUDO=		${ENVVARS}
.  else
SUDO!=		command -v doas >/dev/null && \
		echo '${ENVVARS} doas' || \
		echo 'sudo -E ${ENVVARS}'
.  endif
.else
SUDO=		${ENVVARS}
.endif

SETSEXT=	tar.xz
SETSDIR=	sets/${ARCH}

.if ${ARCH} == "evbarm-aarch64"
KERNEL=		netbsd-GENERIC64.img
LIVEIMGGZ=	https://nycdn.netbsd.org/pub/NetBSD-daily/HEAD/latest/evbarm-aarch64/binary/gzimg/arm64.img.gz
.elif ${ARCH} == "i386"
KERNEL=		netbsd-SMOL386
KDIST=		https://smolbsd.org/assets
SETSEXT=	tgz
.else
KERNEL=		netbsd-SMOL
KDIST=		https://smolbsd.org/assets
LIVEIMGGZ=	https://nycdn.netbsd.org/pub/NetBSD-daily/HEAD/latest/images/NetBSD-10.99.12-amd64-live.img.gz
.endif

LIVEIMG=	NetBSD-${ARCH}-live.img

# sets to fetch
RESCUE=		rescue.${SETSEXT} etc.${SETSEXT}
BASE?=		base.${SETSEXT} etc.${SETSEXT}
PROF=		${BASE} comp.${SETSEXT}
COMP=		${BASE} comp.${SETSEXT}
BOZO=		${BASE}
IMGBUILDER=	${BASE}

.if ${UNAME_M} == "x86_64"
ROOTFS?=	-r ld0a
.else
# unknown / aarch64
ROOTFS?=	-r ld5a
.endif

# any BSD variant including MacOS
DDUNIT=		m
UNAME_S!=	uname
.if ${UNAME_S} == "Linux"
DDUNIT=		M
.endif
FETCH=		curl -L -s
.if ${UNAME_S} == "NetBSD"
FETCH=		ftp
.endif

# extra remote script
.if defined(CURLSH) && !empty(CURLSH)
EXTRAS+=	-c ${CURLSH}
.endif

# default memory amount for a guest
MEM?=		256
# default port redirect, gives network to the guest
PORT?=		::22022-:22
# default size for disk built by imgbuilder
SVCSZ?=		128

IMGSIZE?=	512

# QUIET: default to quiet mode with Q=@, use Q= for verbose
Q=@

ARROW="➡️"
CHECK="✅"

help:
	$Qgrep '.*:$$' Makefile

kernfetch:
	$Qmkdir -p kernels
	$Qif [ ! -f kernels/${KERNEL} ]; then \
		echo "${ARROW} fetching kernel"; \
		if [ "${ARCH}" = "amd64" -o "${ARCH}" = "i386" ]; then \
			${FETCH} -o kernels/${KERNEL} ${KDIST}/${KERNEL}; \
		else \
			${FETCH} -o- ${KDIST}/kernel/${KERNEL}.gz | \
				gzip -dc > kernels/${KERNEL}; \
		fi; \
	fi

setfetch:
	$Qecho "${ARROW} fetching sets"
	$Q[ -d ${SETSDIR} ] || mkdir -p ${SETSDIR}
	$Qfor s in ${SETS}; do \
		[ -f ${SETSDIR}/$${s} ] || ${FETCH} -o ${SETSDIR}/$${s} ${DIST}/sets/$${s}; \
	done

pkgfetch:
	[ -d ${PKGS} ] || mkdir ${PKGS}
	for p in ${ADDPKGS};do \
		[ -f ${PKGS}/$${p}* ] || ftp -o ${PKGS}/$${p}.tgz ${PKGSITE}/$${p}*; \
	done

rescue:
	${MAKE} setfetch SETS="${RESCUE}"
	${SUDO} ./mkimg.sh -m 20 -x "${RESCUE}" ${EXTRAS}
.if ${UNAME_S} != "Darwin"
	${SUDO} chown ${USER}:${GROUP} ${.TARGET}-${ARCH}.img
.endif

base:
	$Q${MAKE} setfetch SETS="${BASE}"
	$Qecho "${ARROW} creating root filesystem (${IMGSIZE}M)"
	$Q${SUDO} ./mkimg.sh -i ${SERVICE}-${ARCH}.img -s ${SERVICE} \
		-m ${IMGSIZE} -x "${BASE}" ${EXTRAS}
.if ${UNAME_S} != "Darwin"
	$Q${SUDO} chown ${USER}:${GROUP} ${SERVICE}-${ARCH}.img
 	@${SUDO} chown ${USER}:${GROUP} ${SERVICE}-${ARCH}.img
.endif
	$Qecho "${CHECK} image ready: ${SERVICE}-${ARCH}.img"

prof:
	${MAKE} setfetch SETS="${PROF}"
	${SUDO} ./mkimg.sh -i ${.TARGET}-${ARCH}.img -s ${.TARGET} -m 1024 -k kernels/${KERNEL} \
		-x "${PROF}" ${EXTRAS}
.if ${UNAME_S} != "Darwin"
	${SUDO} chown ${WHOAMI} ${.TARGET}-${ARCH}.img
.endif

# for use with sailor, needs rework
#imgbuilder:
#	${MAKE} setfetch SETS="${BASE}"
#	# build the building image if NOIMGBUILDERBUILD is not defined
#	if [ -z "${NOIMGBUILDERBUILD}" ]; then \
#		${SUDO} SVCIMG=${SVCIMG} ./mkimg.sh -i ${.TARGET}-${ARCH}.img -s ${.TARGET} \
#			-m 512 -x "${BASE}" ${EXTRAS} && \
#		${SUDO} chown ${USER}:${GROUP} ${.TARGET}-${ARCH}.img; \
#	fi
#	# now start an imgbuilder microvm and build the actual service
#	# image unless NOSVCIMGBUILD is set (probably a GL pipeline)
#	if [ -z "${NOSVCIMGBUILD}" ]; then \
#		dd if=/dev/zero of=${SVCIMG}-${ARCH}.img bs=1${DDUNIT} count=${SVCSZ}; \
#		./startnb.sh -k kernels/${KERNEL} -i ${.TARGET}-${ARCH}.img -a '-v' \
#			-h ${SVCIMG}-${ARCH}.img -p ${PORT} ${ROOTFS} -m ${MEM}; \
#	fi

live:	kernfetch
	echo "fetching ${LIVEIMG}"
	[ -f ${LIVEIMG} ] || ${FETCH} -o- ${LIVEIMGGZ}|gzip -dc > ${LIVEIMG}

buildimg: kernfetch
	$Qmkdir -p images
	$Qecho "${ARROW} building the builder image"
	$Q${MAKE} MOUNTRO=y SERVICE=build IMGSIZE=320 base
	$Qmv -f build-${ARCH}.img images/

fetchimg:
	$Qmkdir -p images
	$Qecho "${ARROW} fetching builder image"
	$Qif [ ! -f images/${BUILDIMG} ]; then \
		${FETCH} -o- ${BUILDIMGURL}.xz | xz -dc > images/${BUILDIMG}; \
	fi

build:	kernfetch
	$Qif [ ! -f images/${.TARGET}-${ARCH}.img ]; then \
		${MAKE} buildimg; \
	fi
	$Qmkdir -p tmp
	$Qrm -f tmp/build-*
	# save variables for sourcing in the build vm
	$Qecho "${ENVVARS}"|sed 's/\ /\n/g' > tmp/build-${SERVICE}
	$Qecho "${ARROW} starting the builder microvm"
	$Q./startnb.sh -k kernels/${KERNEL} -i images/${.TARGET}-${ARCH}.img -c 2 -m 512 \
		-p ${PORT} -w . -x "-pidfile qemu-${.TARGET}.pid" &
	# wait till the build is finished, guest removes the lock
	$Qwhile [ -f tmp/build-${SERVICE} ]; do sleep 0.2; done
	$Qecho "${ARROW} killing the builder microvm"
	$Qkill $$(cat qemu-${.TARGET}.pid)
.if ${UNAME_S} != "Darwin"
	$Q${SUDO} chown ${USER}:${GROUP} ${SERVICE}-${ARCH}.img
.endif
