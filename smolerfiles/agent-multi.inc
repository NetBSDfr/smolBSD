# Multi-agent login profile and config-check launcher for the agents image
# (crush, maki, codeur): cmd.sh looks for each agent's configuration on the
# host share or through fw_cfg, prints a banner explaining the three agents
# and their config files, auto-launches the single configured agent, or
# shows a menu; the choice is recorded in ~/.agentrc and .profile runs that
# agent inside tmux on first login.
#
# Requires smolerfiles/agent.inc before this INCLUDE (USER/WORKDIR set).
#
# INCLUDE smolerfiles/agent-multi.inc

# codeur mkdir()s only its own codeur/ leaf dirs under the XDG bases
RUN mkdir -p .config/codeur .local/state .local/share .cache

RUN cat <<EOF >.profile
cd /home/$NBUSER
if ! pgrep -x crush >/dev/null 2>&1 && ! pgrep -x maki >/dev/null 2>&1 && ! pgrep -x codeur >/dev/null 2>&1; then
[ -f .agentrc ] && . ./.agentrc
case "\\\$AGENT_CHOICE" in
crush | maki | codeur)
printf "\n\n⌚ wait for ${LIGHTGREEN}\\\$AGENT_CHOICE${NORMAL} to load...\n\n"
\\\$AGENT_CHOICE
exit
;;
esac
fi
PS1="[\\w]\$ "
EOF

RUN cat <<EOF >cmd.sh
 # NOTE: the parser drops any heredoc body line starting with # (even
 # indented), so this generated cmd.sh carries no comments; and it needs
 # no shebang: ./cmd.sh runs through the shell fallback when execve finds
 # none, exactly like SMOLerfile.crush's does.

 CRUSH_CONF=""
 MAKI_CONF=""
 CODEUR_CONF=""

 for f in /mnt/crush.json /var/qemufwcfg/opt/org.smolbsd.file.crush
 do
 [ -f "\\\$f" ] && { CRUSH_CONF="\\\$f"; break; }
 done
 for f in /mnt/init.lua /mnt/.maki/init.lua /var/qemufwcfg/opt/org.smolbsd.file.makiconf
 do
 [ -f "\\\$f" ] && { MAKI_CONF="\\\$f"; break; }
 done
 for f in /mnt/config.ini /mnt/.config/codeur/config.ini /var/qemufwcfg/opt/org.smolbsd.file.codeurconf
 do
 [ -f "\\\$f" ] && { CODEUR_CONF="\\\$f"; break; }
 done

 # codeur can run on env vars (injected with -e) instead of config.ini
 [ -z "\\\$CODEUR_CONF" ] && printenv CODEUR_API_URL >/dev/null 2>&1 && CODEUR_CONF=env

 # use <found-config> <target> <persisted-state-dir-in-share>
 use() {
 mkdir -p \\\$(dirname "\\\$2")
 cp "\\\$1" "\\\$2"
 chmod 644 "\\\$2"
 [ -n "\\\$(ls -A "\\\$3" 2>/dev/null)" ] && cp -rf "\\\$3"/* \\\$(dirname "\\\$2")/
 }

 N=0
 [ -n "\\\$CRUSH_CONF" ] && N=\\\$((N+1))
 [ -n "\\\$MAKI_CONF" ] && N=\\\$((N+1))
 [ -n "\\\$CODEUR_CONF" ] && N=\\\$((N+1))

 printf "\n\n🤖 ${LIGHTGREEN}agents${NORMAL} — three AI coding agents in one microvm\n"
 printf " they run inside ${LIGHTGREEN}tmux${NORMAL} (prefix ${LIGHTGREEN}^b${NORMAL}): quitting the agent halts the microvm\n"
 printf " sessions and memory persist across reboots if the share carries share/<agent>/\n"

 if [ "\\\$N" = 1 ]; then

 AGENT=""
 [ -n "\\\$CRUSH_CONF" ] && AGENT=crush
 [ -n "\\\$MAKI_CONF" ] && AGENT=maki
 [ -n "\\\$CODEUR_CONF" ] && AGENT=codeur
 printf "\n ${LIGHTGREEN}\\\$AGENT${NORMAL} is the only agent with a configuration\n"
 printf "\n⌨️ Press ${LIGHTGREEN}enter${NORMAL} to start it, ${LIGHTGREEN}s${NORMAL} for a shell: "
 read ans
 case "\\\$ans" in
 [sS]) CHOICE=shell ;;
 *) CHOICE=\\\$AGENT ;;
 esac

 else

 if [ -n "\\\$CRUSH_CONF" ]; then S1="${CHECK} \\\$CRUSH_CONF"; else S1="no crush.json"; fi
 if [ -n "\\\$MAKI_CONF" ]; then S2="${CHECK} \\\$MAKI_CONF"; else S2="no init.lua"; fi
 if [ "\\\$CODEUR_CONF" = env ]; then S3="${CHECK} env vars"
 elif [ -n "\\\$CODEUR_CONF" ]; then S3="${CHECK} \\\$CODEUR_CONF"
 else S3="no config.ini"; fi

 printf "\n ${LIGHTGREEN}1${NORMAL} 🪨 crush charmbracelet, Go TUI agent crush.json \\\$S1\n"
 printf " ${LIGHTGREEN}2${NORMAL} 🍣 maki tontinton, Rust agent, Lua config init.lua \\\$S2\n"
 printf " ${LIGHTGREEN}3${NORMAL} 🧩 codeur bapt, tiny C agent, OpenAI-compat config.ini \\\$S3\n"
 printf "\n pass configs to the microvm with\n"
 printf " ${LIGHTGREEN}-w <dir>${NORMAL} containing crush.json / init.lua / config.ini\n"
 printf " ${LIGHTGREEN}-E crush=/p/crush.json,makiconf=/p/init.lua,codeurconf=/p/config.ini${NORMAL}\n"
 printf " ${LIGHTGREEN}-e CODEUR_API_URL=...,CODEUR_API_KEY=...,CODEUR_MODEL=...${NORMAL} runs codeur bare\n"

 CHOICE=""
 while [ -z "\\\$CHOICE" ]; do
 printf "\n Type ${LIGHTGREEN}1${NORMAL}, ${LIGHTGREEN}2${NORMAL} or ${LIGHTGREEN}3${NORMAL} to start an agent, ${LIGHTGREEN}s${NORMAL} for a shell: "
 read ans
 case "\\\$ans" in
 1) CHOICE=crush ;;
 2) CHOICE=maki ;;
 3) CHOICE=codeur ;;
 [sS]) CHOICE=shell ;;
 *) printf "1 (crush), 2 (maki), 3 (codeur) or s (shell)? " ;;
 esac
 done

 fi

 # copy the found config (and persisted state) for the chosen agent
 [ "\\\$CHOICE" = crush ] && [ -n "\\\$CRUSH_CONF" ] && use "\\\$CRUSH_CONF" crush.json /mnt/share/crush
 [ "\\\$CHOICE" = maki ] && [ -n "\\\$MAKI_CONF" ] && use "\\\$MAKI_CONF" .config/maki/init.lua /mnt/share/maki
 [ "\\\$CHOICE" = codeur ] && [ -n "\\\$CODEUR_CONF" ] && [ "\\\$CODEUR_CONF" != env ] && use "\\\$CODEUR_CONF" .config/codeur/config.ini /mnt/share/codeur

 printf 'AGENT_CHOICE=%s\\n' "\\\$CHOICE" >.agentrc

 [ "\\\$CHOICE" = shell ] && exec ksh
 exec su ${NBUSER} -c "tmux -u new"
EOF
RUN chmod +x cmd.sh

# the generated dotfiles and XDG parents are written by root (postinst runs
# chrooted as root); hand everything to the agent user so it can create
# leaf dirs and state at runtime
RUN chown -R $NBUSER:$NBUSER /home/$NBUSER
