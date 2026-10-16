# Shared bootstrap for tmux-launched agent services (maki, crush, codeur,
# zeroclaw): environment, /etc/rc.local, agent user, tmux configuration.
#
# Requires ENV NBUSER=<name> before this INCLUDE.
#
# INCLUDE smolerfiles/agent.inc

ENV LANG=en_US.UTF-8
ENV TERM=tmux-256color
ENV PATH=${PATH}:/usr/pkg/bin

RUN cat <<EOF >/etc/rc.local
hostname ${NBUSER}
ulimit -n 4096
EOF

RUN echo 'eval \$(resize)' >>/etc/rc.local
RUN echo 'printf "\nℹ️ When shutting down, ${LIGHTGREEN}Ctrl-A Ctrl-X${NORMAL} to exit the microvm\n\n"' >>/etc/rc.local

USER $NBUSER
WORKDIR /home/$NBUSER

RUN touch .hushlogin

RUN cat <<EOF >.tmux.conf
set -g status off
set -g default-terminal "screen-256color"
set -g mode-keys vi
set -g set-clipboard on
set -g default-shell /usr/pkg/bin/bash
EOF
