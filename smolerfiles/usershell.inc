ENV TERM=tmux-256color
ENV LANG=en_US.UTF-8

RUN rm -f /etc/shrc
RUN cat <<EOF >>/etc/profile
PS1="\$(printf '\e[1;31m\${USER}\e[1;37m@${HOSTNAME}\e[0m$ ')"
EOF

RUN echo "hostname ${HOSTNAME}" >>/etc/rc.local && \
	echo 'eval \$(resize)' >>/etc/rc.local && \
	echo ". /etc/include/shutdown" >>/etc/rc

ARG HOMEDIR=/home/${USERNAME}

RUN <<EOF
[ -d "$HOMEDIR" ] || makehome="-m"
useradd \$makehome $USERNAME
chsh -s $USERSHELL $USERNAME
touch ${HOMEDIR}/.hushlogin
echo 'HISTFILE="\$HOME/.history"' >> ${HOMEDIR}/.profile
chown -R $USERNAME ${HOMEDIR}
EOF
