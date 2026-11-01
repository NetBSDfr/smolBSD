# smolcracy

Omarchy-style (DHH) keyboard-first tiling desktop for smolBSD: X11 +
i3 + catppuccin-mocha, no Wayland stack. X runs inside QEMU via
virtio-gpu-gl (`-X`), the session starts automatically and runs as
user **smol** (passwordless `doas`).

## Prerequisites (host)

- QEMU >= 10 built with SDL + GL (`~/src/qemu/build/qemu-system-x86_64`),
  required by `-X` for virtio-gpu-gl.
- The SMOLX kernel (`kernels/amd64/smolbsdx`, includes virtiodrm +
  LinuxKPI), same as smolBSD xbase.

## Build

    ./smoler.sh build -y smolerfiles/SMOLerfile.smolcracy

Kill any running VM first: `make build` waits on `lsof` of the image,
and rebuilding while a VM holds the image open can produce a corrupt
image.

## Run

    ./startnb.sh -k kernels/amd64/smolbsdx \
                 -i images/smolcracy-amd64:latest.img -X window

`-X` modes: `window` (1280x800), `fullscreen`, or `WxH`.
Booting lands you straight in i3. Exiting the session (logout, i3
exit) tears down X and makes QEMU exit (session `power_off` +
`-no-reboot`).

## Keybindings

`$mod` = Super.

| Keys | Action |
|---|---|
| Return | terminal (alacritty, catppuccin TOML theme) |
| `Shift+t` | btop system monitor |
| space | rofi launcher (card, centered; `apps` chip) |
| Escape | power menu: lock / logout / reboot / power off |
| Ctrl+l | lock (i3lock) |
| Print | area screenshot (maim) to `~/Pictures/` |
| q or w | close window |
| t / f | floating toggle / fullscreen toggle |
| j | split/layout toggle |
| b | hide/show bar |
| arrows / Shift+arrows | focus / move window |
| minus, equal (+Shift for height) | resize focused window |
| 1-9 | switch workspace |
| Shift+1-9 | move window to workspace and follow |
| Mod1+Shift+1-9 | move window, stay on current workspace |
| Tab / Shift+Tab | next / previous workspace |
| Ctrl+Tab | workspace back-and-forth |
| s / Shift+s | show scratchpad / move window to scratchpad |
| Shift+e | logout (exits i3 -> closes the VM window) |

## Look and feel

Catppuccin mocha throughout (`#1e1e2e` base, `#cba6f7` mauve accent):
dark top bar with workspace pills, thin mauve border on the focused
window (2px pixel borders), 12px rounded corners + soft shadows via
picom, JetBrains Mono Nerd Font terminal, Inter UI. Prompt is
p10k-flavored (starship): mauve directory pill, dark clock pill, green
command duration, pink exit-code box on failure. Rofi is a centered
card: crust background, periwinkle (`#9199cb`) border, lavender
(`#45475a`) selection chips. A flat background is the intentional
default (Omarchy uses a matching solid color per theme).

## Session components

| Component | Role |
|---|---|
| i3 | WM (vanilla pkgsrc i3: no gaps, `bar mode toggle`, see gotchas) |
| i3status | cpu + clock (memory sensors are unsupported on NetBSD) |
| rofi | app launcher (`drun`, centered card) + power menu (`dmenu`) |
| picom | compositor, **xrender backend**: glx over virgl (Mesa 21.3.7) freezes presentation after minutes |
| dunst | notifications |
| alacritty | terminal (GPU; per-glyph font fallback, which urxvt lacks for nerd-font icons) |
| i3lock, maim, xdotool, clipit, xidle, hsetroot | lock, screenshots, scripting, clipboard, idle, wallpaper |

## Image layout (`service/smolcracy/`)

    etc/session.sh        boots Xorg, starts stage as smol, power_off
    etc/xorg.conf         virtio-gpu + DRI setup
    etc/rc                service rc additions
    packages/home/smol/   dotfiles (.xsession, .Xresources, .config/*)
    postinst/             pkg repo, profile, smol user + doas
                      (fonts.conf lives under packages/usr/X11R7/etc/fonts/)

Boot flow: `CMD sh /etc/session.sh` -> Xorg as root -> `doas`
(pkgsrc, `permit nopass root as smol`) -> `.xsession` pins
`PATH`/`HOME`/`LANG`/`SHELL`, starts dbus, retries `xrdb -merge` until
Xorg accepts resources, then i3.

## Gotchas (learned the hard way)

- **i3 splits `exec` commands on `;` ignoring quotes** -- use `cmd1 &&
  cmd2` (no quotes) or a script file (see `powermenu.sh`).
- **rofi 2.0 rasi**: `config.rasi` holds ONLY the `configuration {}`
  block; theme goes in a separate file referenced by
  `@theme "path"` after the block, without trailing semicolon;
  use dot-state selectors (`element.selected.normal`).
- **Xorg drops early `xrdb` writes**: the first seconds after X starts
  are unreliable; `.xsession` retries in the background and the
  terminal keybind merges Xresources again before each launch.
- **btop needs `LANG=C.UTF-8`** (exported by session.sh).
- Inside the guest the X display is **:1** and root's console already
  exports `DISPLAY`/`XAUTHORITY` (Xorg got no `-auth`, `.Xauthority`
  is empty: pass `XAUTHORITY` unset to client tests, not a path).
- **Oct-2026 base OpenPAM breaks `su`/`sudo`/`login`** (pam_start
  fails): session.sh picks runtime `SMOLL` = pkgsrc `doas` (fallback
  `daemon`, root); sudo pkg is not installed.
- **Xorg re-enables DPMS at VT acquire** ~1s after start: plain
  `xset -dpms` in `.xsession` loses the race -> blank "Display output
  is not active"; sleep 2, then disable (see `.xsession`).
- **bash cannot right-align the starship prompt** (`$(starship
  prompt)` sees no tty): keep time/duration inline on line 1; the
  `[time]` module has no `symbol` key, put glyphs in `format`.
- A killed menu leaves `~/.cache/rofi.pid`; remove it before relaunch.

## Debugging from the serial console

The muxed console is a root shell. Capture the screen from inside the
guest and stream it out over the serial line (host screenshots of the
SDL window are unreliable):

    (maim /tmp/shot.png &); sleep 3; pkill -9 -x maim
    base64 /tmp/shot.png            # then decode host-side

Per-window capture (`maim -i $(xdotool search --name rofi) out.png`)
stays live even when the root-window path goes stale.
