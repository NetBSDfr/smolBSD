# Improving p9 on NetBSD — the smolBSD story

*Oct 2026 — branch `supasmol` of the NetBSD src tree, shipped through
smolBSD as the `smolbsd` kernel plus the `smolset` userspace overlay.*

---

## 0. Context

NetBSD ships a usable but little-exercised 9p client stack:

| layer | code | role |
|---|---|---|
| transport | `sys/dev/pci/vio9p.c` | virtio-9p (virtqueue) transport driver |
| protocol | `sys/dev/pci/virtio*` | generic virtio core |
| filesystem | `usr.sbin/puffs/mount_9p/` | userspace PUFFS filesystem, 9P2000(.u) dialect |
| wire codec | `nineproto.[ch]` | message encode/decode |

smolBSD runs NetBSD guests under QEMU with a virtio-9p share as a data
channel — and eventually as the root candidate — which put far more
traffic through this stack than typical NetBSD users: pipelined
write streams, 2000-file directories, SIGTERM-driven unmounts at boot
remount, symlinks, and host-owned files with real uids.

Almost everything below was first observed as a hang, panic or wrong
byte in that environment. Upstreaming is on hold (project policy), so
the work ships as: kernel `assets/<arch>/smolbsd` + overlay
`assets/<arch>/smolset.tar.xz` (contains the rebuilt `mount_9p`),
fetched like regular sets by smolBSD (`bmake kernfetch setfetch`).

Reference implementations consulted throughout: the Linux 9p client
(`fs/9p`, `net/9p`), the qemu `virtfs` server (multi-threaded
fsworkers), the OASIS virtio specification, and the 9P2000/9P2000.u/
9P2000.L protocol docs.

---

## 1. Kernel `vio9p`

### 1.1 The big one: no pipelining, and a deterministic 512-byte stall

**Symptom.** Any write stream beyond a couple of kilobytes (tar into
the share, `dd` in 1 MB blocks) stalled forever on the second 512-byte
chunk. Big directories panicked the kernel (`KASSERT` in
`vio9p_read`). One RPC in flight meant throughput ≈ one host round
trip per 512 bytes.

**Cause.** The driver had *one* pair of shared DMA buffers
(`sc_buf_tx/rx`), *one* dmamap pair, and *one* expected tag. The
virtqueue, however, is designed for pipelining: `mount_9p`'s frame
layer happily issues TWRITE tag 35 while RRESPONSE 34 is still in
flight, and qemu's fsworker threads even complete requests
*out of order*. With one shared buffer, a pipelined reply always
clobbers the request still being waited on. A previous attempt to
paper over this ("discard unreplied on write") actually *ate* a
still-wanted reply, producing the stall exactly at NetBSD's
`BUFSIZ = 512` chunk boundary.

**Fix — per-request slot pool (the pipelining rewrite).**
- `VIO9P_NREQ = 8` request slots; per-slot `kmem` buffers and
  per-slot tx/rx dmamaps.
- `sc_slot2pool[]` (sized `vq_num`, init −1) maps virtio
  descriptor-slot → pool slot. The cookie count equals `vq_num` when
  indirect descriptors are used, which is the virtio-defined bound on
  outstanding requests — hence the fixed pool.
- `write()`: block for a free slot (`cv_timedwait_sig`, 1 s; a signal
  returns EAGAIN and the caller dies = natural backpressure), publish
  `itag/inflight` **before** `virtio_enqueue_commit()`.
- `read()`: dequeue FIFO, sync the *dequeued slot's* rx map, and only
  accept the reply if `itag[pool] == rtag && inflight[pool]` —
  unknown replies are discarded and the loop continues (out-of-order
  tolerant). The accepted reply is staged in `sc_stage` and consumed
  in chunks (`buf_rx_len/offset`).
- Timeout = repoll the ring (the ring is the truth, the interrupt is
  a hint); `request_done()` became a pure `cv_broadcast` + `selnotify`
  with no state mutation at all.
- `close()`: clear the pool, `memset` slot2pool back to −1, keep the
  generation-guarded drain (§1.3).

**A gotcha that cost one boot:** clearing `sc_req_inflight[pool]`
*before* the itag comparison makes every reply look stale ("discarded"
→ `server invalid response to Tversion: 0`). Always compute `known`
first, clear after.

**Inspiration.** Linux `fs/9p/virtio.c` (per-request sg lists,
virtqueue cookies as request handles) and the virtio spec's split
virtqueue model; the 8-deep pool mirrors the Linux client's fixed
request array (`p9_req_t pool`) and, at one remove, Plan 9's
`rendezvous`-per-message idiom.

### 1.2 Short replies, slot leaks, and interrupt hygiene

**Symptoms / causes / fixes.**
- A RREAD shorter than the requested chunk returned `EINVAL`: fixed
  to `len = MIN(len, uio_resid)` — a short reply is legal in 9p.
  (Inspiration: Linux `p9_parse_header` tolerance.)
- Failed `virtio_enqueue_reserve()` without `virtio_enqueue_abort()`
  leaked descriptor slots until the ring deadlocked: added the abort.
  (Pure NetBSD virtio-core API discipline.)
- `request_done()` used to set the reply state unconditionally, so
  stale interrupts clobbered fresh requests: now only when state ==
  REQUESTING; a spurious REPLIED with an empty queue returns to
  REQUESTING instead of confusing the waiter.

### 1.3 Stale replies across sessions, and the boot-remount race

**Symptom.** Intermittent boot failure at the rw-root remount:
`server invalid response to Tversion: 0` (answered by a leftover
`R_CLUNK` of the previous session). Also intermittent total hangs.

**Cause.** PUFFS unmount = SIGTERM the server, reap, close. Two races:
1. Replies of the old virtqueue session survived close() and leaked
   into the next mount's Tversion exchange.
2. The kill/reap ordering means `close()` of the old mount can run
   *after* `open()` of the new one — so a naive drain-at-close ate
   the **new** session's first reply.

**Fix.**
- `sc_expect_tag` matching (tag at offset 5 of the 9p header, LE) +
  a bounded drain-at-close (≤10 rounds, `mutex_exit` + `tsleep`
  between rounds).
- **`sc_gen` generation counter**: `open()` bumps it; the old
  `close()` notices the bump and aborts its drain. This is the piece
  that fixed the boot remount.
- `read()`'s wait loop must let the process die: a `cv_timedwait_sig`
  return of ERESTART/EINTR (signal) → return EAGAIN and unwind;
  EWOULDBLOCK (timeout) → keep waiting. An earlier "swallow
  everything" version made mounts unkillable, which deadlocked the
  whole remount path (`close()` never ran → next mount rejected
  EAGAIN "already requesting") — and `MALLOC_OPTIONS=GU` turned it
  into timing roulette, which is why the same test passed and failed
  unpredictably for days.

**Inspiration.** Generation/reset semantics from the virtio spec
(device generations after reset), the drain-on-close pattern found in
NetBSD USB drivers, and PUFFS' own documented SIGTERM-then-reap
unmount contract (Antti Kantee's puffs design notes).

### 1.4 The signed-char bug

The reply buffer is `char *`; reading the tag byte sign-extended
anything ≥ 0x80 (legit tag 0x80 became 0xFF80 = 65408), so fresh
replies were misclassified as stale and discarded. Fixed with
`(unsigned char)` casts. Worth recording because the C rule is
famous and the bug still happened.

### 1.5 Debug knob

`VIO9P_DEBUG` (DLOG) makes the guest roughly 10× slower and logs
~10 MB/min — enabled it once, watched a 512-byte dmesg turn into a
24 KB one, shipped it compiled out.

---

## 2. Userspace `mount_9p`

### 2.1 Lost stat fields (the first bug found)

**Symptom.** `ls -l` through the share showed wrong/zero uid/gid for
host-owned files — stat was "losing" fields through the mount.

**Cause.** Two compounding problems in the 9P2000.u stat codec:
- `n_uid`/`n_gid`/`n_muid` in 9P2000.u are **4-byte numbers**, but a
  constant (`P9PROTO_NUNAME_UNSPECIFIED`) was typed small enough to
  make the parser take a name-only path (and truncate).
- Servers such as qemu with `security_model=none` put *numeric
  strings* ("1000") in the uid/gid *name* fields; mount_9p looked the
  names up in the password database, failed, and substituted nobody.

**Fix.**
- `nineproto.h`: uid types widened to `uint32`.
- `ustr2uid()`/`gstr2gid()`: numeric fallback when the name parses as
  a decimal id.
- `proto_getstat()`/`proto_make_stat()`: prefer the numeric
  `n_uid`/`n_gid` fields when they are ≠ `~0`, names as fallback —
  i.e. exactly the id-mapping policy Linux' client uses.

**Inspiration.** Linux `net/9p/idmap` behaviour and the 9P2000.u
rstat spec (numeric fields introduced precisely because names proved
unmappable across systems).

### 2.2 Symlinks did not exist

**Symptom.** `ln -s` on the share crashed or produced wrong types;
`ls -ld` gave EINVAL; `readlink` returned empty.

**Cause.** 9P2000.u encodes a symlink as a *file* whose mode carries
the `CPERM_SYMLINK` bit and whose target is written to the file;
qemu persists it as the `user.virtfs.symlink.target` xattr. A plain
TREAD of such a file returns **0 bytes**, and the QID `QTLINK` bit
was being ignored, so nothing ever became `VLNK`. 9P2000.u has no
TREADLINK at all.

**Fix.**
- `qid2vattr()`: `QTLINK` → `VLNK` (also fixes `ls -ld` and
  `stat -f %T`).
- `symlink()`: Tcreate with `perm | CPERM_SYMLINK`, Twrite the
  target, clunk, walk — mirroring Linux `v9fs_vfs_symlink` for dotu
  sessions byte for byte.
- `readlink()`: plain TREAD first; when it yields nothing, send the
  **9P2000.L `TREADLINK(72)`/`RREADLINK(73)`** — qemu answers those
  even on a `.u` negotiated session, as does a modern Linux server.

**Inspiration.** Linux `fs/9p` dotu symlink path; the 9P2000.L spec
(`Rreadlink`); qemu's `virtfs` local backend for the xattr detail.

### 2.3 Stale attribute mirror (truncation, bad APPEND)

**Symptom.** After `write`, `cat` showed an older, shorter file;
`>>` appends landed at a stale offset; `chmod` didn't stick to the
next `stat` unless remounted.

**Cause.** The puffs kernel keeps **no attribute cache** unless
`PUFFS_KFLAG_CACHE_FS_TTL` is set, so every `VOP_GETATTR` reaches the
filesystem — and the filesystem answered from its own stale mirror
(`pn_va`): the write path never updated `va_size/va_bytes` (reads are
bounded by the mirror), so PUFFS_IO_APPEND wrote at the old size and
subsequent reads truncated at it.

**Fix.** `write()` now updates the mirror (`va_size`, `va_bytes`);
`setattr()` refreshes the mirror with a `do_getattr()` after TWSTAT.
(An attr-cache TTL was *not* enabled: freshness beats speed for a
network fs whose server may change files under us.)

**Inspiration.** Linux' client-side revalidation on every `-EIO`-free
operation plus `cache=` mount option semantics; puffs man-page
documenting `PUFFS_KFLAG_CACHE_FS_TTL` as explicitly opt-in.

### 2.4 Errors were all "Protocol error"

**Symptom.** ENOENT, EACCES, ENOTEMPTY … every server-side failure
surfaced to the guest as `Protocol error` (EPROTO).

**Cause.** `Rerror` with a *string* (9P2000.u/2012 style) was mapped
wholesale to EPROTO.

**Fix.** An error-string → `errno` table covering the spellings both
Linux and NetBSD servers emit (case-insensitive prefix match), plus a
leak fix for the Rerror payload. `open(2)` on a missing file now
returns ENOENT.

**Inspiration.** Linux `net/9p/protocol.c::v9fs_errno_from_errstr()`
(plus a NetBSD strerror list for the local-server case).

### 2.5 Hardening and style

- `puffs_pn_new()` failures and the `makep9pnode` abort replaced by
  proper `err(1,)` diagnostics (a silent-death crash was ultimately a
  NULL `pni_vtype` deref via `puffs_newinfo_setvtype()` in the symlink
  op — found by removing the abort).
- Frame-buffer recycling only where a `p9pbuf` is reused (fresh
  `p9pbuf_makeout()` output buffers already start at the right
  offset).
- KNF audit of all touched files (80 columns, canonical comment
  forms, file-local label style).

---

## 3. How it was tested

A guest test loop (`service/p9test`, untracked dev service) boots a
smolBSD image whose boot-time mount_9p is swapped for the candidate,
remounts, and runs `test.sh` through the share itself:

- `stat` of a host-owned file (`0750`, uid/gid 1000) → §2.1
- host→guest and guest→host `ln -s` / `readlink` → §2.2
- host *appends during the run*, guest must see it → §2.3 mirror
- 2000-file directory `ls` → §1.1 (the old KASSERT panic)
- 10× `umount`/`mount` loop → §1.3 (close/open races)
- guest `dd` + tar into the share → §1.1 (pipelining)

Reports are written back over the 9p share; the VM auto-halts; serial
logs on the host. Runs 15→20 tracked the progression: first
ever `test.sh` completion (run "dbg", pipelining), KNF build green
(run16), VM-built binary shipped via smolset (run19), host-toolchain
build shipped via smolset (run20) — all green including 10/10
remounts.

**Visible effects today** (published kernel + smolset):

```sh
time dd if=/dev/zero bs=1m count=128 of=/mnt/t bs=1m  # was: stall
( dd ... f1 & dd ... f2 & ls -lR /mnt )               # concurrent OK
mkdir /mnt/bigdir; seq 2000 | (cd /mnt/bigdir && xargs touch)
ls -l /mnt/bigdir | tail -1                           # was: KASSERT panic
cat /mnt/nope                                         # was: Protocol error
stat -f 'uid=%u gid=%g perm=%p' /mnt/hostfile         # was: wrong fields
```

---

## 4. Shipping (how the fixes reach a guest)

- **Producer** (`supasmol`): `./mksmolset.sh <arch>` builds only the
  binaries listed in `diverges/<arch>.list` (currently
  `usr.sbin/puffs/mount_9p`) with `nbmake`, installs into the
  bootstrap DESTDIR, and tars the result → `obj/smolset.<arch>.tar.xz`.
- **Ingress**: `assets/{amd64,i386,aarch64}/` holds `smolbsd` (kernel,
  renamed — it carries more than upstream now), its `smolbsd.sha256`,
  and `smolset.tar.xz`.
- **Consumer** (smolBSD): `kernfetch` validates kernel + sha256;
  `setfetch` resolves each set from KDIST → NetBSD daily → local, and
  `smolset.tar.xz` is extracted **last** so it overrides the stock
  `mount_9p`. Images therefore ship the fixed stack with no other
  deviation from stock NetBSD sets.
- GitHub Actions builds base+rescue images per arch on every push and
  publishes them; the whole fetch path (kernel, sha, smolset) is
  exercised by that pipeline.

## 5. Deliberately not done

- No 9P2000.L dialect negotiation beyond TREADLINK (no .L walk
  variants, xattrs, locks).
- No direct `P9DIRREAD`-style bulk readdir (the .u TREADDIR chunking
  through the slot pool is fast enough for now).
- Upstreaming parked: the work rides in smolBSD until the NetBSD
  community has appetite for it.

---

## 6. Performance: caching, a fatter pipe, and what fell out

The correctness work made 9p *usable*; a file-heavy workload still
paid full protocol cost per operation. A `stat` of every file in a
2000-file directory meant 2000 × (WALK + STAT + CLUNK) round trips,
each one an interrupt — with zero caching, even `ls` twice in one
second did twice the work. Two levers, both shipped this round.

### 6.1 Attribute caching with a TTL (decision reversal)

§5 used to say "no attr caching (staleness > speed)". That was right
when there was nothing to tune; there now is. mount_9p sets
`PUFFS_KFLAG_CACHE_FS_TTL` with a 1-second default (`-o ttl=N`,
`ttl=0` restores the old no-cache behaviour). The kernel puffs layer
keeps attributes fresh for TTL seconds; the daemon still mirrors
writes, so self-invalidation is unchanged. Worst case staleness for
host-side changes is now bounded and *chosen*: 1 second, by default,
down from "forever, in the old mirror code" and up from "nothing".
A mount-time print states the effective TTL and msize.

### 6.2 msize 16 KB → 128 KB

`P9P_DEFREQLEN` (client) and `VIO9P_MAX_REQLEN` (kernel) move
together: one 128 KB READ replaces eight 16 KB ones. The kernel pool
grows to 8 slots × 2 × 128 KB ≈ 2 MB. QEMU's server performs no
msize capping (it rejects only < 8192 and the transport limit is
~4 MB), and the client adopts whatever the server echoes at
TVERSION, so a stingier server just gets a smaller pipe. The real
win is bulk data; the microbench below barely notices, being
latency-bound.

### 6.3 The bug hunt: three fixes found via stalls

Shipping this required debugging two reproducible guest hangs, which
turned out to be three separate bugs:

1. **Wrong TREADLINK opcode (the real one).** mount_9p sent 9P2000.L
   readlink as type 72. In the Linux extension enum **72 is
   `Tmkdir`** — readlink is **22**. QEMU tried to decode the
   fid-only payload as a mkdir, failed, and called
   `virtio_error()` — which marks the entire device *broken*
   permanently; from then on the queue was ignored and the guest
   wedged at its first symlink. One line in `nineproto.h` (22/23).
2. **Level-interrupt livelock.** QEMU drives the virtio-mmio line
   change-only; a lost deassert left the ioapic pin latched asserted
   while the device ISR read 0, and the IST_LEVEL stub re-EOI'd at
   ~50 k/s, starving softints. virtio-mmio is spec'd edge-triggered
   (`pic=off` microvm notwithstanding): `intr_establish` now uses
   `IST_EDGE`.
3. **Lost doorbells.** With an ioeventfd doorbell and a host that
   coalesces unchanged levels, a kick or a completion signal can
   vanish silently. The read path re-kicks the queue when its 1 s
   wait expires with requests in flight (`virtio_kick_vq()`, new
   core helper; idempotent, cheap, never observed firing in healthy
   runs — insurance, not a crutch).

### 6.4 Numbers (p9test microvm, KVM, host fsdev; before → after)

`before`: stock pipelined stack, no cache, msize=16384.
`after`: TTL=1 s cache, msize=131072. Same bench.sh through the
same share; wall seconds, lower is better:

| bench (files)            | before | after |
|--------------------------|--------|-------|
| stat_glob (2000 stats)   |  1.32  | 0.54  |
| cat_small (2000 r/w/c)   |  2.30  | 1.78  |
| ls_cold (2000, first)    |  0.57  | 0.56  |
| ls_warm (2000, second)   |  0.70  | 0.10  |
| write500 (create)        |  0.65  | 0.69  |
| unlink500                |  0.67  | 0.43  |
| cat_8k (200 × 8 KB)      |  0.27  | 0.25  |
| dd_1m (1 MB read)        |  0.03  | 0.03  |

The cache is the headline: repeated metadata traffic gets 2.4–7×
(`ls` warm is nearly free); writes are untouched (uncached on
purpose); cold passes are unchanged, as they must be. msize is
invisible at this scale — every bench number is round-trip
latency, and QEMU's fsdev is a local directory — but it is the
lever for bulk payloads, which is what real file syncing does.

A whole `test.sh` (all of §3) now finishes in ~50 s of guest time,
down from a run that used to take minutes before caching existed.
