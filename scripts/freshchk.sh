#!/bin/sh

# if the host does not have internet access
[ -n "$NONET" ] && exit 0

. service/common/choupi

URL=$1
DEST=$2
FILE=${1##*://}
FILE=${FILE%\*} # clean wildcard from http://foo/bar* URL
DIR=${FILE%/*}
FETCH=$(dirname $0)/fetch.sh

mkdir -p db/$DIR

remotefile=$($FETCH -I $URL | \
	sed -E -n 's/last-modified:[[:blank:]]*([[:print:]]+)/\1/ip' | \
	base64 || echo 0)
localfile=$(cat db/$FILE 2>/dev/null || echo 0)

if [ -s "${DEST}" ] && [ "$remotefile" = "$localfile" ]; then
	echo "${CHECK} ${FILE##*/} is fresh"
	exit 0
fi

echo "$remotefile" > db/$FILE
echo "${ARROW} fetching ${FILE##*/}"

exit 1
