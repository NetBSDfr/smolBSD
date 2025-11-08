ARCH!=		ARCH=${ARCH} scripts/uname.sh -m
MACHINE!=	scripts/uname.sh -p
OS!=		uname -s

.-include "service/${SERVICE}/options.mk"
.-include "service/${SERVICE}/own.mk"

VERS?=		11
PKGVERS?=	11.0
# for an obscure reason, packages path use uname -p...
DIST?=		https://nycdn.netbsd.org/pub/NetBSD-daily/netbsd-${VERS}/latest/${ARCH}/binary
PKGSITE?=	https://cdn.netbsd.org/pub/pkgsrc/packages/NetBSD/${MACHINE}/${PKGVERS}/All
KDIST=		${DIST}
WHOAMI!=	whoami
USER!= 		id -un
GROUP!= 	id -gn
BUILDIMG=	build-${ARCH}.img
BUILDIMGPATH=	images/${BUILDIMG}
BUILDIMGURL=	https://github.com/NetBSDfr/smolBSD/releases/download/latest/${BUILDIMG}

SERVICE?=	${.TARGET}
# guest root filesystem will be read-only
.if defined(MOUNTRO) && ${MOUNTRO} == "y"
EXTRAS+=	-o
.endif

# variables to transfer to mkimg.sh
ENVVARS=	SERVICE=${SERVICE} \
		ARCH=${ARCH} \
		PKGVERS=${PKGVERS} \
		MOUNTRO=${MOUNTRO} \
		PKGSITE=${PKGSITE} \
		ADDPKGS="${ADDPKGS}" \
		MINIMIZE=${MINIMIZE}

.if ${WHOAMI} != "root" && !defined(NOSUDO) # allow non root builds
SUDO!=		command -v doas >/dev/null && \
		echo '${ENVVARS} doas' || \
		echo 'sudo -E ${ENVVARS}'
.else
SUDO=		${ENVVARS}
.endif

SETSEXT=	tar.xz
SETSDIR=	sets/${ARCH}
PKGSDIR=	pkgs/${ARCH}

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
LIVEIMGGZ=	https://nycdn.netbsd.org/pub/NetBSD-daily/HEAD/latest/images/NetBSD-11.99.3-amd64-live.img.gz
.endif

LIVEIMG=	NetBSD-${ARCH}-live.img

# sets to fetch, defaults to base
SETS?=		base.${SETSEXT} etc.${SETSEXT}

.if ${ARCH} == "amd64"
ROOTFS?=	-r ld0a
.else
# unknown / aarch64
ROOTFS?=	-r ld5a
.endif

# any BSD variant including MacOS
DDUNIT=		m
.if ${OS} == "Linux"
DDUNIT=		M
.endif
FETCH=		scripts/fetch.sh
FRESHCHK=	scripts/freshchk.sh

# extra remote script
.if defined(CURLSH) && !empty(CURLSH)
EXTRAS+=	-c ${CURLSH}
.endif

# default memory amount for a guest
MEM?=		256
# default port redirect, gives network to the guest
PORT?=		::22022-:22

IMGSIZE?=	512
DSTIMG?=	images/${SERVICE}-${ARCH}.img

# QUIET: default to quiet mode with Q=@, use Q= for verbose
Q=@

CHOUPI=	./service/common/choupi
ARROW!=	. ${CHOUPI} && echo "$$ARROW"
CHECK!=	. ${CHOUPI} && echo "$$CHECK"
CPU!=	. ${CHOUPI} && echo "$$CPU"
FREEZE!=. ${CHOUPI} && echo "$$FREEZE"

help:	# This help you are reading
	$Qgrep '^[a-z]\+:.*#' Makefile

kernfetch:
	$Qmkdir -p kernels
	$Qif [ "${ARCH}" = "amd64" ] || [ "${ARCH}" = "i386" ]; then \
		${FRESHCHK} ${KDIST}/${KERNEL} kernels/${KERNEL} || \
			${FETCH} -o kernels/${KERNEL} ${KDIST}/${KERNEL}; \
	else \
		${FRESHCHK} ${KDIST}/kernel/${KERNEL}.gz kernels/${KERNEL} || \
			curl -L -o- ${KDIST}/kernel/${KERNEL}.gz | \
				gzip -dc > kernels/${KERNEL}; \
	fi

setfetch:
	@[ -d ${SETSDIR} ] || mkdir -p ${SETSDIR}
	$Qfor s in ${SETS}; do \
		${FRESHCHK} ${DIST}/sets/$${s} ${SETSDIR}/$${s} || \
			${FETCH} -o ${SETSDIR}/$${s} ${DIST}/sets/$${s}; \
	done

pkgfetch:
	@[ -d ${PKGSDIR} ] || mkdir -p ${PKGSDIR}
	$Qfor p in ${ADDPKGS};do \
		${FRESHCHK} ${PKGSITE}/$${p}* ${PKGSDIR}/$${p}.tgz || \
			${FETCH} -o ${PKGSDIR}/$${p}.tgz ${PKGSITE}/$${p}*; \
	done

fetchall: kernfetch setfetch pkgfetch

base:
	$Qecho "${CPU} destination architecture: ${ARCH} / ${MACHINE}"
	# if we are on the builder vm, don't fetchall again
	$Q[ -f tmp/build-${SERVICE} ] || ${MAKE} fetchall
	$Qecho "${ARROW} creating root filesystem (${IMGSIZE}M)"
	$Qmkdir -p images
	$Q${SUDO} ./mkimg.sh -i ${DSTIMG} -s ${SERVICE} \
		-m ${IMGSIZE} -x "${SETS}" ${EXTRAS}
	$Q${SUDO} chown ${USER}:${GROUP} ${DSTIMG}
	$Qif [ -n "${MOUNTRO}" ]; then \
		echo "${FREEZE} system root filesystem will be read-only"; fi
	$Qecho "${CHECK} image ready: ${DSTIMG}"

buildimg:
	$Qecho "${ARROW} building the builder image"
	$Q${MAKE} SERVICE=build base

fetchimg:
	$Qmkdir -p images
	$Qecho "${ARROW} fetching builder image"
	$Q${FRESHCHK} ${BUILDIMGURL}.xz || \
		curl -L -o- ${BUILDIMGURL}.xz | xz -dc > ${BUILDIMGPATH}

build: fetchall # Build an image (with SERVICE=$SERVICE from service/)
	$Qif [ ! -f ${BUILDIMGPATH} ]; then \
		${MAKE} buildimg; \
	fi
	$Qmkdir -p tmp
	$Qrm -f tmp/build-*
	# save variables for sourcing in the build vm
	$Qecho "${ENVVARS}" | \
		sed -E 's/[[:blank:]]+([A-Z_]+)/\n\1/g;s/=[[:blank:]]*([[:print:]]+)/="\1"/g' > \
		tmp/build-${SERVICE}
	$Qecho "${ARROW} starting the builder microvm"
	$Q./startnb.sh -k kernels/${KERNEL} -i ${BUILDIMGPATH} -c 2 -m 1024 \
		-p ${PORT} -w . -x "-pidfile qemu-${.TARGET}.pid" &
	# wait till the build is finished, guest removes the lock
	$Qwhile [ -f tmp/build-${SERVICE} ]; do sleep 0.2; done
	$Qecho "${ARROW} killing the builder microvm"
	$Qkill $$(cat qemu-${.TARGET}.pid)
	$Q${SUDO} chown ${USER}:${GROUP} ${DSTIMG}

rescue: # Build a rescue image
	${MAKE} SERVICE=rescue build

live: kernfetch # Build a live image
	$Qecho "fetching ${LIVEIMG}"
	[ -f ${LIVEIMG} ] || curl -L -o- ${LIVEIMGGZ}|gzip -dc > ${LIVEIMG}
