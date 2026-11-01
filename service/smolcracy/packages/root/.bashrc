# smolBSD bash init — Omarchy-flavored: starship prompt, lsd listings
case $- in *i*) ;; *) return ;; esac
case ":$PATH:" in *:/usr/pkg/bin:*) ;; *) PATH=$PATH:/usr/pkg/bin:/usr/pkg/sbin ;; esac
case ":$PATH:" in *:/usr/X11R7/bin:*) ;; *) PATH=$PATH:/usr/X11R7/bin ;; esac
export PATH EDITOR
EDITOR=vi
command -v starship >/dev/null && eval "$(starship init bash)"
if command -v lsd >/dev/null; then
	alias ls='lsd'
	alias ll='lsd -l'
	alias la='lsd -a'
	alias lt='lsd --tree'
fi
alias grep='grep --color=auto'
