# Converts a SMOLerfile to a smolBSD service

set -e

usage()
{
	echo "usage: $0 [--build-arg KEY=val ...] [-t tag] [-y] <SMOLerfile>"
	exit 1
}

IMGTAG="latest"
while [ $# -gt 1 ]; do
	case ${1} in
	--build-arg)
		shift
		[ "${1#*=}" = "${1}" ] && usage
		BUILDARGS="${BUILDARGS}${BUILDARGS:+,}${1}"
		;;
	-t|--tag)
		shift
		IMGTAG="$1"
		;;
	-y)
		YES=y
		;;
	esac
	shift
done

lastp="$1"

if [ $# -lt 1 ] || [ ! -f "$lastp" ]; then
	usage
fi

mkdir -p tmp
smolerfile=$(mktemp tmp/SMOLerfile.XXXXXX)

while IFS= read -r line
do
	case "$line" in
	INCLUDE\ *)
		cat ${line##* }
		;;
	*)
		printf "%s\n" "$line"
		;;
	esac
done <$lastp >$smolerfile

case $lastp in *.smol) SERVICE=${lastp%.smol}; SERVICE=${SERVICE##*/};; esac

TMPOPTS=$(mktemp tmp/options.mk.XXXXXX)
# Dockerfile compatibility
sed -n 's/LABEL \(smolbsd\.\)\{0,1\}\(.*=.*\)/\2/p' $smolerfile | \
	awk -F= '{ printf "%s=%s\n", toupper($lastp), $2 }' \
	>${TMPOPTS}

. ./${TMPOPTS}

export CHOUPI=y
. service/common/funcs
. service/common/choupi

if [ -z "$SERVICE" ];then
	echo "${ERROR} no service name, exiting"
	exit 1
fi

servicedir="service/${SERVICE}"

if [ -d "$servicedir" ]; then
	echo "${INFO} $SERVICE already exists, recreating"
	for f in etc/rc options.mk postinst
	do
		rm -rf "${servicedir}/${f}"
	done
	rm -f etc/${SERVICE}.conf
fi

for d in etc postinst
do
	mkdir -p ${servicedir}/${d}
done

postnum=0
postinst="${servicedir}/postinst/postinst-${postnum}.sh"
etcrc="${servicedir}/etc/rc"

sed 's/"//g' ${TMPOPTS} >${servicedir}/options.mk

# setup the chroot for RUN executions
cat >$postinst<<_EOF
#!/bin/sh

set -e

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
grep -q '^ADDPKGS' ${servicedir}/options.mk || \
	echo "ADDPKGS=pkgin pkg_tarup pkg_install sqlite3 curl rsync" \
		>>${servicedir}/options.mk

USER=root
SHELL_CMD=${SHELL_CMD:-/bin/sh}
WORKDIR="/"

postnum=1 # 0 was basic header
postinst="${postinst%-*}-${postnum}.sh"
args="${postinst%-*}.args"
printf '' >"$args"

shhead()
{
	printf '%s\n\n' "#!${SHELL_CMD}" >"$postinst"
	cat >>"$postinst"<<-EOHEAD

	export CHOUPI=y
	. ../service/common/funcs
	. ../service/common/choupi

	EOHEAD
}

shhead

while read -r line
do
	# strip comments
	case "$line" in \#*) continue;; esac

	# normalize to spaces and no trailing spaces
	line=$(printf '%s\n' "$line" | tr -s '\t ' ' ' | sed 's/[[:space:]]*$//')

	# there was a <<EOF
	if [ -n "$heretag" ]; then
		# in heredoc, append until tag
		if [ "$line" != "$heretag" ]; then
			printf '%s\n' "$line"|sed 's/"/\\"/g' >>"$postinst"
		else
			[ -n "$prehere" ] && echo "$heretag" >>"$postinst"

			echo \" >>"$postinst"
			heretag=
			prehere=
			posttag=
		fi
		continue
	fi

	# normal KEY VAL line
	if [ -z "$multiline" ]; then
		key="${line%% *}"
		val="${line#* }"
	else # && \ multiline
		val="${line}"
	fi

	case "$val" in
	# multi lines breaks
	*\\)
		multiline="$multiline${val%\\} "
		continue
		;;
	esac

	val="$multiline$val"; multiline=""

	case "$key" in
	FROM)
		case "$val" in
		*img)
			echo "FROMIMG=${val}" >> ${servicedir}/options.mk
			;;
		*)
			echo "SETS=${val}," | sed 's/\(:[^,]*\)*,/\.${SETSEXT}\1 /g' \
				>> ${servicedir}/options.mk
			;;
		esac
		;;
	ENV)
		echo "export $val" | tee -a "$etcrc" "$postinst" "$args" \
			>/dev/null
		;;
	ARG)
		arg=${val%%=*}
		[ "$arg" != "${val}" ] && default=${val#*=} || default=""
		printf '%s\n' "${arg}=\${${arg}:-${default}}; export $arg" | \
			tee -a "$postinst" "$args" >/dev/null
		;;
	SHELL)
		# -c is useless for us as we execute a script
		SHELL_CMD=$(echo "${val}"|jq -r '[.[] | select(. != "-c")] | join(" ")')
		# SHELL has changed, create a new postinst script
		postnum=$((postnum + 1))
		postinst="${postinst%-*}-${postnum}.sh"
		shhead
		# bring ARGs
		cat "$args" >>"$postinst"
		echo >>"$postinst"
		;;
	RUN)
		case "$val" in
			*\<\<*)
				# worst case: cat   <<EOF     > foo.conf
				#                     ^^^^^^^^^^^^^^^^^^
				#                     posthere
				#             ^^^     ^^^     ^^^^^^^^^^
				#             prehere heretag   posttag
				prehere=${val%%<<*} # command before heredoc
				posthere=${val#*<<} # all after heredoc
				heretag=${posthere%% *} # tag itself
				posttag=${posthere#${heretag}} # after tag
				[ -n "$prehere" ] && prehere="$prehere <<$heretag"
				# remove any heredoc specfier
				heretag=$(printf '%s' "$heretag"|tr -d "'\"")
				printf '%s\n' \
					"chroot . su ${USER} -c \"cd ${WORKDIR} && ${prehere}${posttag}" \
					>>"$postinst"
				;;
			*)
				escaped=$(printf '%s' "$val" | sed 's/"/\\"/g')
				printf '%s\n' "chroot . su ${USER} -c \"cd ${WORKDIR} && ${escaped}\"" \
					>>"$postinst"
				;;
		esac
		;;
	EXPOSE)
		# PUBLISH comes from smolbsd LABEL
		if [ -n "$PUBLISH" ]; then
			ports="$PUBLISH"
		# Non-Dockerfile compatible but convenient syntax
		elif [ "${val%:*}" != "$val" ]; then
			ports="$val"
		else
			echo "${WARN} smolbsd.publish LABEL needed to EXPOSE"
		fi

		if [ -n "$ports" ]; then
			for pair in $(echo $ports|tr ',' ' '); do
				portfrom=${pair%:*}
				portto=${pair#*:}
				[ -n "${portfrom}" ] && [ -n "${portto}" ] && \
					hostfwd="${hostfwd}${hostfwd:+,}::${portfrom}-:${portto}"
			done
			[ -n "$hostfwd" ] && \
				echo "hostfwd=$hostfwd" >>etc/${SERVICE}.conf
		fi
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
			if [ "${dst#\$}" != "$dst" ]; then # dst is a variable
				# too large but macOS BRE compatible
				dst=$(echo "$dst"|sed 's,\${*\([^}]*\)}*,${\1#/},')
			fi
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
		WORKDIR="$val"
		echo "cd ${val}" >>"$etcrc"
		;;
	CMD|ENTRYPOINT)
		printf "\n# entrypoint\n" >>"${etcrc}"
		if [ "$USER" != "root" ]; then
			printf '%s' "su $USER -c \"" >>"${etcrc}"
			ENDQUOTE="\""
		fi

		printf '%s' "$val" >>"${etcrc}"
		echo $ENDQUOTE >>"${etcrc}"
		;;
	*)
		;;
	esac
done < $smolerfile

cat >>${etcrc}<<_ETCRC

. /etc/include/shutdown
_ETCRC
cat >>etc/${SERVICE}.conf<<_ETCCONF
imgtag=$IMGTAG
use_pty=$USE_PTY
_ETCCONF

echo "${CHECK} ${SERVICE} service files generated"
if [ -z "$YES" ]; then
	printf '%s' "${ARROW} press enter to build ${SERVICE} image or ^C to exit"
	read dum
fi

rm -f tmp/*

[ "$(uname -s)" = "NetBSD" ] && MAKE=make || MAKE=bmake

$MAKE SERVICE=${SERVICE} BUILDARGS="${BUILDARGS}" IMGTAG=":${IMGTAG}" build
