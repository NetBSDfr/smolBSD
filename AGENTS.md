# Repository Guidelines

## Project Structure & Module Organization
Core build tooling lives at `mkimg.sh` and `startnb.sh`. Services are grouped under `service/<name>` with optional `postinst/` hooks and `etc/rc` startup scripts; shared snippets sit in `service/common`. Host overlays live in `etc/`, NetBSD sets in `sets/<arch>/`, VM configs in `etc/*.conf`, the Flask dashboard in `app/`, static assets in `www/`, and automation artifacts in `tests/`.

## Build, Test, and Development Commands
- `bmake kernfetch` pulls the matching NetBSD kernel for the active `ARCH`.
- `make rescue` or `make <service>` assembles the root image and emits `<service>-<arch>.img`.
- `./startnb.sh -f etc/<vm>.conf -d` launches a VM using the matching config; drop `-d` to stream QEMU logs.
- `cd tests && make test` runs the full suite; use `make unit`, `make integration`, or `./test_runner.sh <target>` for narrower checks.
- `pip install -r app/requirements.txt` provisions the Flask API dependencies when exercising UI or API tests.

## Coding Style & Naming Conventions
Shell scripts target POSIX `sh`; keep constructs portable, use hard tabs for block indentation, and avoid Bash-specific helpers. Run `shellcheck` via `cd tests && make shellcheck` before posting. Python modules follow PEP 8 (four-space indents, snake_case names) and should log through `logging.getLogger`. Service directories and config files stay lowercase with hyphens, and generated images keep the `<service>-<arch>.img` pattern.

## Testing Guidelines
Changes that touch build tooling, services, or the app must pass `cd tests && make test`. Name new shell tests `test_*.sh` and hook them into `tests/Makefile` when they warrant a target. Use `make unit` for quick script checks, `make integration` for cross-component coverage, and the service goals to validate layout and runtime options. System tests rely on QEMU; if the host lacks virtualization, call that out in your PR and capture the subset you ran.

## Commit & Pull Request Guidelines
Recent history favors `type(scope): summary` (e.g., `feat(tests): add service audit`); keep subjects imperative and under 50 characters. Squash fixups before review, and explain the motivation and test evidence in the PR description. Link issues when present, attach screenshots or terminal captures for UI or lifecycle changes, and highlight any new dependencies or breaking behavior.

## Security & Configuration Tips
`postinst/` scripts run as root on the build host, so avoid absolute paths or host-specific mutations. Treat `etc/*.conf` details as sensitive: do not commit secrets or plaintext keys. When mirroring assets, stick with the HTTPS endpoints already captured in the `Makefile`.
