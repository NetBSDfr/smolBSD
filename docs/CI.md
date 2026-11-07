# smolBSD CI

## Workflows

### main.yml — image builds
Builds VM images (`img` workflow_dispatch input). `paths-ignore` on
`smolerfiles/*` so tool-image pushes don't double-trigger.

### smoler.yml — tool image builds
- Triggers: push to `main` with `paths: smolerfiles/*`, or
  `workflow_dispatch` with `dockerfiles` input (space-separated paths).
- Push path selects files via `git diff --name-only HEAD~1` filtered by
  the `DFILES` regex (`(Dock|SMOL)erfile.(crush|clawd|...|maki|...)`)
  => multi-file changes must land in ONE commit.
- Builds amd64 + aarch64 under TCG via `./smoler.sh build -y`, pushes
  images to ghcr.io. NOTE: `smolcracy` is NOT in the DFILES regex; the
  smolcracy image is built through main.yml.

### release-watch.yml — nightly pin bumper
- Cron `0 1 * * *` UTC (~02:00 Madrid winter) + manual dispatch with
  `dry_run` boolean (default true = report only).
- Watches GitHub releases: tontinton/maki (MAKI_VERSION in
  SMOLerfile.maki), charmbracelet/crush (CRUSH_VERSION in
  SMOLerfile.crush), afjcjsbx/picoclaw (GHRELEASE in Dockerfile.clawd).
- Gates on NetBSD amd64+arm64 release assets existing; missing asset =>
  tool skipped with a report line. `SMOLerfile.smolcracy` pins are
  intentionally NEVER touched.
- On change: ONE bump commit -> push to main -> explicit
  `gh workflow run smoler.yml -f dockerfiles="..."`.

## Why the explicit dispatch (important)
1. A push made with the default `GITHUB_TOKEN` does NOT re-trigger other
   workflows (GitHub recursion guard) — pushing a bump alone would never
   build. Hence the explicit `workflow_dispatch`.
2. Dispatching via the API requires the `actions: write` scope. A
   top-level `permissions:` block grants ONLY what it lists:
   `contents: write` alone implicitly set `actions: none` and the
   dispatch died with `403 Resource not accessible by integration`
   after a successful bump+push (run 42360063326, fixed in 43599be).
   Any permissions block here must keep BOTH `contents: write` AND
   `actions: write`.

## PENDING VALIDATION (test when the next real upstream bump lands)
The bot's own dispatch line has not yet run successfully end-to-end:
- day-1 run 42360063326 bumped+pushed, then 403'd at dispatch (fixed in
  43599be; build was triggered manually as run 42360189191).
- Until the first post-fix release bump happens, the "bump commit +
  smoler.yml dispatched BY THE BOT + green run" path is unproven.
TODO (next real bump): confirm the release-watch run is green and a
smoler.yml `workflow_dispatch` run appears without manual intervention.

## Debugging recipes
```sh
gh run list --workflow release-watch.yml --limit 3
gh run view <id>
gh api repos/NetBSDfr/smolBSD/actions/jobs/<job-id>/logs | tail
# day-1 report lines sit just above the "Z dry_run=" marker in the log
```
Side-effect gotcha: the bot pushes directly to main, so local main goes
behind; `git pull --rebase` before pushing local fixes.

## KNOWN FAILURE MODE: "latest" release republish race (hit 2026-11-07)
main.yml ("Build smolBSD image", every push except its own paths-ignore:
`**.md`, `www/**`, `app/**`, `smolerfiles/*`, `smoler.yml`,
`release-watch.yml`) ends by force-republishing
builder images (`build-<arch>.img.xz`) into the shared GitHub `latest`
release (softprops action). smoler.yml's `fetchimg` downloads those same
assets with `curl | xz -dc` and NO checksum verification (.sha256 is only
used for the freshness cache with `|| true`).

Timeline of the incident: 3 pushes ~10 min apart => 3 overlapping
main.yml republishes (finishing 09:35, 09:37, 09:40); smoler run
dispatched 09:32:48 fetched `build-evbarm-aarch64.img.xz` mid-replacement
=> corrupt builder disk => builder VM booted silently and never came up
(no console output, ssh :22022 never answered) => step 5 hangs until the
6h job timeout. Symptom signature: log stops right after
`qemu-system-aarch64: warning: driftfix 'slew' ...`.

Mitigations:
- DONE 2026-11-07 (Makefile): fetchimg verifies the downloaded xz
  against the published .sha256, retrying 3x; a corrupt download now
  fails the build loudly instead of hanging on a zombie builder VM.
- DONE 2026-11-07 (release-watch.yml): the bot waits for the
  push-triggered main.yml to finish before dispatching smoler.yml, so
  automated bumps can no longer race the republish.
- STILL TRUE for manual smoler.yml dispatches: check
  `gh run list --workflow main.yml --status in_progress` first.
  Longer-term idea: per-run asset names instead of shared 'latest'.
