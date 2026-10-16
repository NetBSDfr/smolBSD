# Shared login profile and config-check launcher for tmux agent services
# (maki, crush, codeur): .profile runs the agent in tmux on first login,
# cmd.sh looks for the agent configuration on the host share or through
# fw_cfg, copies it in and starts the tmux session.
#
# Requires smolerfiles/agent.inc before this INCLUDE (USER/WORKDIR set).
# Set these ARGs before this INCLUDE:
#   AGENT          agent binary name (default: NBUSER)
#   AGENT_EMOJI    banner emoji (default: 🪟)
#   CONF_FILES     space-separated config candidates, host share first
#   CONF_TARGET    destination path, relative to the user home
#   CONF_NAME      config filename shown in the warning
#   CONF_VAR       fw_cfg key used with -E
# Optional:
#   CONF_SHARE       host share dir carrying persisted state (default: none)
#   CONF_MODE        chmod mode of the copied config (default: 644)
#   CONF_ENV_FALLBACK  space-separated env vars; if any is set, launch anyway
#   CONF_HINT        extra hint line appended to the warning
#
# INCLUDE smolerfiles/agent-launch.inc

ARG AGENT=${NBUSER}
ARG AGENT_EMOJI=🪟
ARG CONF_MODE=644
ARG CONF_SHARE=
ARG CONF_ENV_FALLBACK=
ARG CONF_HINT=

RUN cat <<EOF >.profile
cd /home/$NBUSER
if ! pgrep ${AGENT} >/dev/null 2>&1; then
	printf "\n\n${AGENT_EMOJI} ${LIGHTGREEN}${AGENT}${NORMAL} runs inside ${LIGHTGREEN}tmux${NORMAL} with prefix ${LIGHTGREEN}^b${NORMAL}\n"
	printf "\n⌨️  Press ${LIGHTGREEN}enter${NORMAL} to start the session"
	read x
	printf "\n⌚ Wait for ${LIGHTGREEN}${AGENT}${NORMAL} to load...\n\n"

	${AGENT}

	exit
fi
PS1="[\\w]\$ "
EOF

RUN cat <<EOF >cmd.sh
#!/bin/sh

for f in ${CONF_FILES}
do
	if [ -f "\\\$f" ]; then
		mkdir -p $(dirname ${CONF_TARGET})
		cp "\\\$f" ${CONF_TARGET}
		[ -d "${CONF_SHARE}" ] && cp -rf ${CONF_SHARE}/* $(dirname ${CONF_TARGET})/
		chown -R $NBUSER /home/$NBUSER
		chmod ${CONF_MODE} ${CONF_TARGET}
		exec su ${NBUSER} -c "tmux -u new"
	fi
done

for v in ${CONF_ENV_FALLBACK}; do
	if printenv "\\\$v" >/dev/null; then
		exec su ${NBUSER} -c "tmux -u new"
	fi
done

printf "⚠️ no ${CONF_NAME} passed from the host, either:\n"
printf "\n- add ${LIGHTGREEN}-E ${CONF_VAR}=/path/to/${CONF_NAME}${NORMAL} to the command line"
printf "\n- or copy ${CONF_NAME} to a directory and add ${LIGHTGREEN}-w /path/to/directory${NORMAL}\n"
[ -n "${CONF_HINT}" ] && printf "\n- ${CONF_HINT}\n"
ksh
EOF
RUN chmod +x cmd.sh
