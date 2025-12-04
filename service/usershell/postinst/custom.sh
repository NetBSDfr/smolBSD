#!/bin/sh

rm -f etc/shrc # wipe defaults
cat >>etc/profile<<EOF
HOSTNAME=\$(hostname)
PS1="\$(printf '\e[1;31m\${USER}\e[1;37m@\${HOSTNAME}\e[0m$ ')"
EOF
