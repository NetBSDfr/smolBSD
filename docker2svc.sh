#!/bin/sh

# Converts a basic Dockerfile to a smolBSD service

set -e

if [ $# -lt 1 ] || [ ! -f "$1" ]; then
	echo "usage: $0 <Dockerfile>"
	exit 1
fi

dockerfile=$1
ECHON="/bin/echo -n"

mkdir -p tmp
TMPOPTS=$(mktemp tmp/options.mk.XXXXXX)
# Dockerfile compatibility
sed -n 's/LABEL \(smolbsd\.\)\{0,1\}\(.*=.*\)/\2/p' $dockerfile | \
	awk -F= '{ printf "%s=%s\n", toupper($1), $2 }' \
	>${TMPOPTS}

. ./${TMPOPTS}

export CHOUPI=y
. service/common/funcs
. service/common/choupi

if [ -z "$SERVICE" ];then
	echo "${ERROR} no service name, exiting"
	exit 1
fi
if ! command -v jq >/dev/null; then
	echo "${ERROR} missing jq"
	exit 1
fi

servicedir="service/${SERVICE}"

if [ -d "$servicedir" ]; then
	echo "${INFO} $SERVICE already exists, recreating"
	for f in etc options.mk postinst
	do
		rm -rf "${servicedir}/${f}"
	done
	rm -f etc/${SERVICE}.conf
fi

for d in etc postinst
do
	mkdir -p ${servicedir}/${d}
done
postinst="${servicedir}/postinst/postinst.sh"
etcrc="${servicedir}/etc/rc"

mv ${TMPOPTS} ${servicedir}/options.mk

# setup the chroot for RUN executions
cat >$postinst<<_EOF
#!/bin/sh
if [ ! -f /BUILDIMG ]; then
	echo "${ERROR} NOT IN BUILDER IMAGE! EXITING"
	exit 1
fi
. ../service/common/funcs

rootdir=\$(pwd) # postinst is ran from fake root
cat >etc/profile<<_PROFILE
PATH=\$PATH:/sbin:/usr/sbin:/usr/pkg/bin:/usr/pkg/sbin
export PATH
_PROFILE
cp /etc/resolv.conf etc/
mkdir -p usr/pkg/etc/pkgin
# evbarm-aarch64 repo name is aarch64
ARCH=\${ARCH#evbarm-}
echo "https://cdn.netbsd.org/pub/pkgsrc/packages/NetBSD/\${ARCH}/\${PKGVERS}/All" \
	>usr/pkg/etc/pkgin/repositories.conf
rsynclite /etc/openssl/ \${rootdir}/etc/openssl
_EOF

cat >${etcrc}<<_EOF
#!/bin/sh

. /etc/include/basicrc
. /etc/include/mount9p

_EOF
echo "ADDPKGS=pkgin pkg_tarup pkg_install sqlite3" \
	>>${servicedir}/options.mk

USER=root

grep -v '^$' $dockerfile|while read key val
do
	# normalize to single spaces
	val=$(printf '%s' "$val" | tr -s '\t ' ' ')

	case "$key" in
	FROM)
		case "$val" in
		*img)
			echo "FROMIMG=${val}" >> ${servicedir}/options.mk
			;;
		*)
			echo "SETS=${val}," | sed 's/,/\.${SETSEXT} /g' \
				>> ${servicedir}/options.mk
			;;
		esac
		;;
	ENV)
		echo "export $val" | tee -a "$etcrc" "$postinst" >/dev/null
		;;
	ARG)
		echo "export $val" >>"$postinst"
		;;
	RUN)
		echo "chroot . su ${USER} -c \"${val}\"" >>"$postinst"
		;;
	EXPOSE)
		if [ -n "$PUBLISH" ]; then
			portfrom=${PUBLISH%:*}
			portto=${PUBLISH#*:}
		# Non-Dockerfile compatible but convenient syntax
		elif [ "${val%:*}" != "$val" ]; then
			portfrom=${val%:*}
			portto=${val#*:}
		else
			echo "${WARN} smolbsd.publish LABEL needed to EXPOSE"
		fi

		[ -n "${portfrom}" ] && [ -n "${portto}" ] && \
			echo "hostfwd=::${portfrom}-:${portto}" \
			>>etc/${SERVICE}.conf
		;;
	ADD|COPY)
		src=${val% *}
		dst=${val##* }
		while :; do
			case "$src" in
			--chown=*|--chmod=*|--exclude=*)
				option="${src%%=*}"   # --chown, --chmod, or --exclude
				option="${option#--}" # chown, chmod, or exclude
				value="${src#*=}"     # foo:bar file1 file2
				src="${value#* }"     # file1 file2
				value="${value%% *}"  # foo:bar

				eval "$option=\$value"

				[ "$option" = "exclude" ] && \
					toexclude="${toexclude} --exclude=${value}"
				;;
			*)
				break
				;;
			esac
		done
		case "$src" in
		http*://*)
			[ -d "${dst#/}" ] && outdl=${dst#/}/${src##*/} || outdl=${dst#/}
			echo "ftp -o ${outdl} ${src}" >>"$postinst"
			;;
		*)
			echo "rsynclite ${toexclude} ${src} ${dst#/}" >>"$postinst"
			;;
		esac

		[ -n "$chown" ] && \
			echo "[ -d \"${src#/}\" ] && \
				chroot . sh -c \"chown -R $chown ${dst}\" || \
				chroot . sh -c \"chown -R $chown ${dst}/${src##*/}\"" \
			>>"$postinst"
		[ -n "$chmod" ] && \
			echo "[ -d \"${src#/}\" ] && \
				chroot . sh -c \"chmod -R $chmod ${dst}\" || \
				chroot . sh -c \"chmod -R $chmod ${dst}/${src##*/}\"" \
			>>"$postinst"
		;;
	USER)
		echo "chroot . sh -c \"id ${val} >/dev/null 2>&1 || \
			(useradd -m ${val} && groupadd ${val})\"" \
			>>"$postinst"
		USER=${val}
		;;
	VOLUME)
		echo "share=${val}" >>etc/${SERVICE}.conf
		# avoid mount_9p warning
		[ "${val#/}" = "${val}" ] && val="/${val}"
		echo "MOUNT9P=${val}" >>"$etcrc"
		echo ". /etc/include/mount9p" >>"$etcrc"
		echo "mkdir -p ${val#/}" >>"$postinst"
		;;
	WORKDIR)
		echo "cd ${val}" >>"$etcrc"
		;;
	CMD|ENTRYPOINT)
		printf "\n# entrypoint\n" >>"${etcrc}"
		if [ "$USER" != "root" ]; then
			$ECHON "su $USER -c \"" >>"${etcrc}"
			ENDQUOTE="\""
		fi
		$ECHON "${val}" | \
			jq -j 'if length > 1 then join(" ") else .[0] end' \
			>>"${etcrc}"
		echo $ENDQUOTE >>"${etcrc}"
		;;
	*)
	esac
done

cat >>${etcrc}<<_ETCRC

. /etc/include/shutdown
_ETCRC

echo "${CHECK} ${SERVICE} service files generated"
$ECHON "${ARROW} press enter to build ${SERVICE} image or ^C to exit"
read dum

[ "$(uname -s)" = "NetBSD" ] && MAKE=make || MAKE=bmake

$MAKE SERVICE=${SERVICE} build
