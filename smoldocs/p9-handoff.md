# P9 work handoff — state as of 2026-11-11 (r25, amd64 machine)

Companion to `smoldocs/p9_improvement_smolBSD.md` (the narrative; §6 is
this round's perf work). This file is the operational state: what was
asked, what is done, what is left, for the machine that picks this up.

## Repos & commits (pushed, pull these)

- **NetBSD-src** (fork NetBSDfr/NetBSD-src), branch **`supasmol`**,
  2 new commits:
  - `c2de4f72bef` SMOL: virtio-mmio edge IRQs, vio9p lost-notify
    re-kick, msize 128K  (kernel: IST_EDGE in virtio_mmio_cmdline.c,
    `virtio_kick_vq()` core helper, rekick in vio9p read path,
    VIO9P_MAX_REQLEN 128K, r=1 on softint dispatch)
  - `ab24ce9847a` SMOL: mount_9p attr caching TTL (1 s default,
    `-o ttl=N`, ttl=0 off), 9P2000.L readlink opcode **22/23** (was
    72/73 = TMKDIR in the Linux enum → QEMU marks device broken),
    P9P_DEFREQLEN 128K, new stats.c (SIGINFO per-type counters)
- **smolBSD**, `main`: this doc + improvement doc under `smoldocs/`
  + `service/p9test` & `service/p9build` test services (now tracked).

## Verified (amd64, p9test VM, KVM microvm)

r22–r25 all green: full `test.sh` rc=0, bench rc=0, no cores, zero
"Failed to decode", readlink served as id 22. r25 tested the
*shipping shape*: image baked with the new smolset → the boot mount
itself negotiates msize=131072; total test+bench ~50 s guest time.

Bench before→after (wall s): stat_glob 1.32→0.55, cat_small 2.30→1.55,
ls_warm 0.70→0.10, unlink500 0.67→0.43; writes unchanged (uncached on
purpose). Details: doc §6.

Binaries (gitignored, host-local on the amd64 box — rebuild, don't
fetch from git): kernel `obj/sys/arch/amd64/compile/SMOL/netbsd`,
set `obj/smolset.amd64.tar.xz` (mount_9p-only, same shape as the
shipped set), staged copy in `~/src/smolBSD/sets/amd64/`.

## What remains (aarch64 machine — the reason for this doc)

1. Pull both repos. NetBSD-src supasmol must contain the two commits
   above (`git log --oneline -3` should show `ab24ce9847a` on top).
2. **Rebuild the aarch64 smolset** — the current
   `obj/smolset.aarch64.tar.xz` (2026-10-26) has the OLD mount_9p:
   - needs an evbarm toolchain: `./build.sh -m evbarm -T obj/tooldir.evbarm tools`
     (then `mksmolset.sh aarch64` finds `nbmake-evbarm`; it maps
     aarch64→evbarm for wrapper names);
   - the xorg lines in `diverges/aarch64.list` need a complete
     MesaLib dist in `xsrc-smol/external/mit/` (see commit
     db00d6fedb9). If absent, ship the mount_9p-only shape first:
     `grep -v xorg diverges/aarch64.list > /tmp/9plist && cp /tmp/9plist diverges/aarch64.list && ./mksmolset.sh aarch64; cp /tmp-back`
     (that is what was shipped for amd64; set must contain
     `usr/sbin/mount_9p` dated fresh);
   - if destdir install fails with mkstemp ENOENT, the parent dirs
     are missing (unprivileged install cannot create them):
     `mkdir -p obj/destdir.evbarm/usr/X11R7/{lib/pkgconfig,lib/modules/dri,include}`;
     libdrm also needs `lib/libm` and `lib/libpci` built into
     destdir first (`cd lib/libm && nbmake-evbarm`, same for libpci).
3. **Kernel**: aarch64 SMOL kernel rebuild + publish per doc §4
   (assets `smolbsd` + regenerated `smolbsd.sha256`); the amd64
   kernel asset likewise from the amd64 box or re-built anywhere.
4. Publish per doc §4; GitHub Actions rebuilds images on push, so the
   new set ships after Actions completes.
5. Optional follow-ups (documented, not blocking):
   - vio9p pool slots have no timeout path: a permanently broken
     server (device error) strands INFLIGHT slots forever — consider
     failing requests after N seconds;
   - MesaLib full rsync so the glapi/gallium diverges lines build;
   - 9P2000.L: still only TREADLINK negotiated — audit other dotl
     opcodes before ever using them (the 72/TMKDIR class of bug).

## Machine gotchas (cost hours, respect them)

- **mount_9p has no `.depend`**: objects build in-tree; editing any
  header silently reuses stale `.o`. ALWAYS `rm -f *.o mount_9p`
  before nbmake after header edits, and check the compile lines
  appear in the output.
- p9test VM lifecycle: after `kill -9` ALWAYS re-bake the image
  (`mkimg.sh -s p9test -m 512 -i images/p9test-amd64.img`) or ext2
  corruption panics the next run; remove BOTH pidfiles
  (`qemu-p9test.pid` + `/tmp/p9qemu.pid`) or startnb.sh silently
  refuses.
- QEMU 11: no msize capping (rejects only < 8192, cap ~4 MB);
  `-trace enable='v9fs_*'` needs the separate `-trace` arg form;
  a halted `-d` VM still burns ~90 % CPU.
- Test flow: rc remounts `/mnt/mount_9p.new` from the host share,
  runs `test.sh` then `bench.sh` (both present in `~/src/p9share`
  on the amd64 box; report → `/mnt/report-rc.txt` before halt).
  To bench: share must contain `bench/` dir + `bench.sh`.
