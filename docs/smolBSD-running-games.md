# Running games on smolBSD — Urban Terror notes

Field notes from the first "game appliance" service: **urbanterror**
(`smolerfiles/SMOLerfile.urbanterror` + `service/urbanterror/`).
Urban Terror 4.3.4 (ioquake3 engine) on GLX over virtio-gpu-gl (virgl),
guest kernel SMOLX (`kernels/amd64/smolbsdx`), QEMU >= 10 microvm.

## Appliance design

- `CMD sh /etc/session.sh`: brings up Xorg (:1, modesetting/glamor),
  runs Urban Terror directly — **no window manager**, windowed mode.
- The session (and thus the VM) **halts when the game process exits**.
  That is by design, and it has one big gotcha (see "not a crash" below).
- Launched with `./startnb.sh -X` (adds the GL devices + smolbsdx kernel
  default; qemu < 10 is refused outright).

## Disk image size

`LABEL smolbsd.imgsize` on this service is **6144** — measured, not
picked at random:

| imgsize | result |
|---------|--------|
| 2048 | pkgin aborts: `cache does not have enough space for download, (1483M required but only 1457M are available)` |
| 4096 | build dies with a **transient** `Bus error (core dumped)` from NetBSD `tar` inside the builder VM (`mkimg.sh`, `eval $($TAR xfp $pkg -O +BUILD_INFO ...)`); LOCALBASE then evaluates empty ("extracting .. to ..") |
| 6144 | clean build |

Reference numbers for the closure: 26 packages, **1483 MB download +
1894 MB installed**; `urbanterror-4.3.4.tgz` alone is ~1.4 GB (game
data); gcc12 is the second monster. A pkgin download + its extraction
must both fit the target image, so size it from those two numbers.

## Mouse (ioquake3 + virtio-tablet) — three knobs needed together

The virtio-tablet is an **absolute** device (QEMU normalizes to
0..32767); the kernel (session-12 fix in `sys/dev/virtio/virtio_input.c`,
`WSMOUSEIO_GCALIBCOORDS`) makes the X `ws` driver scale it to pixels.
Desktop use (fluxbox etc.) works with zero config. The engine needed:

1. `+set in_raw 0` — ioquake3 defaults to XInput2 **raw** input, which
   reads the absolute axes as relative deltas: pointer unusably fast
   (~25x, 32767-vs-pixels) **and inverted**.
2. `+set in_nograb 1` — the subtle one. Even with core events, ioquake3
   `XWarpPointer`s to the window center every frame and derives motion
   from the warp delta; with an absolute device the next tablet event
   jumps the pointer back to the host position, adding a phantom delta
   (~2x overspeed, swimmy). Without the grab the game derives deltas
   from the absolute position itself — behaves exactly like the desktop.
3. `+set r_mode -1 +set r_customwidth 1280 +set r_customheight 800` —
   the window must be **exactly the X screen size** so host pointer
   position maps 1:1 to guest cursor. A smaller centered window
   re-scales the pointer range (feels 1.25x off) and lets the cursor
   escape the window; resizing live via `vid_restart` grew the X
   screen past the visible mode (window at old center offset).

Cvars that **did not** work / were worse:

- `r_fullscreen 1` (guest-side) hung video mode setting — the VM froze
  after `vid_restart`. Use a full-size window instead.

The validated command line lives in `service/urbanterror/etc/session.sh`.

## "Crashes" that are not crashes

Because the VM halts when the game exits, **any orderly engine exit
looks like a crash** (frozen last frame, serial dead). Two suspected
crashes were diagnosed over serial:

- no kernel `trap`/`killed` line, no OOM;
- the game log tail showed a clean `==== ShutdownGame ====` —
  ioquake3 **exited voluntarily**; the reason sits earlier in
  `/tmp/urbanterror.log`, which is tmpfs and dies with the halt.

To hunt it: dump more of the log in the post-game `echo` in
`session.sh` (currently `tail -3`) before reproducing.

Suspects for a voluntary exit on "return to main menu"/map load:
`quit`-style menu action reached by a stray click (in nograb mode the
cursor is live everywhere in the window), or UT's engine restart
(Sys_Exec) failing to find its argv0 path outside the wrapper.

## Networking / online play

- startnb uses `-netdev user` with **no port forwarding**. Outbound
  client traffic works, but joining a server can sit at
  **"Awaiting snapshot..."**: ioquake3's connect wait blocks its own
  event loop, so mouse **and** keyboard appear frozen — it is a network
  stall, not a hang. UDP-forwarded slirp or a bridge would fix the
  server-browser/heartbeat flakiness; `start server` (local) needs no
  network and always works.
- A local game ran at **109 fps** on the AMD virgl path — performance
  is a non-issue.

## RAM

The game uses roughly 300 MB; the 2 GB that `-X` defaults to was never
the crash cause (confirmed by the absence of OOM in the halt output).
`-m 4096` is comfortable headroom if X + game + pkgin cache pressure
shows up.

## Ops cheat-sheet

```sh
# build
cd ~/src/smolBSD && rm -f tmp/build-urbanterror && \
  (setsid nohup ./smoler.sh build -y \
   smolerfiles/SMOLerfile.urbanterror >/tmp/ut-build.log 2>&1 &)

# run (4 GB here; -X defaults to 2 GB)
cd ~/src/smolBSD && DISPLAY=:0.0 PATH=$HOME/src/qemu/build:$PATH \
  ./startnb.sh -X -m 4096 -d -t 9100 -i urbanterror-amd64:latest

# screenshot of the host display (agent shells have DISPLAY localhost:11!)
DISPLAY=:0.0 ffmpeg -loglevel error -f x11grab -i :0.0 \
  -frames:v 1 -y /tmp/x.png

# background serial capture (survives the crash, read later)
(setsid nohup sh -c 'exec nc localhost 9100 >>/tmp/serial.log 2>&1' &)
```

Serial console pitfalls (all bitten once):

- qemu serial telnet serves **one client**: any `nc` probe *kicks* the
  background capture and subsequent output is lost. Capture, then never
  probe the same port.
- via plain `nc` you must handshake (`\r\n` first; commands end with
  `\r`), allow several seconds for output, and expect telnet IAC bytes
  (`M-^?{`...) — filter with `tr -d '\000'`.
- commands **do execute** even when nothing echoes back — verify with a
  follow-up read before resending, or edits double-apply.

In-game console (tilde) is the fastest live-tuning channel from the
host — `xdotool key --window $W grave`, type the cvar, Return.
`in_nograb` applies instantly; `in_raw` only at engine input init
(= game restart). Menu clicks can be scripted with absolute-pointer
math: click at `win_x + WIDTH*fx/100`, `win_y + HEIGHT*fy/100`
(`xdotool getwindowgeometry --shell`).

## Open questions / next digging

- [ ] Exact reason ioquake3 exits voluntarily on return-to-menu —
      needs the fuller log dump (change `tail -3` in session.sh).
- [ ] Online play over user-net: try `-netdev stream` (slirp with UDP
      tracking) or bridge; server browser reliability unknown.
- [ ] The 4096-builder `Bus error` in NetBSD tar looked deterministic
      across 3 rebuilds at 4096 and vanished at 2048/6144 — worth a
      retry at 4096 before trusting "transient".
- [ ] `pgrep -fl urban` finds no process while the game runs: what is
      the engine binary actually named? (affects pkill-based restarts)
- [ ] Consider an `etc/urbanterror.conf` (imgtag etc.) like xbase has.
