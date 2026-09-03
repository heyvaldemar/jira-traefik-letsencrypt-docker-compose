# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

_(no unreleased changes yet)_

## [1.3.0] - 2026-09-02

### Security

- **Container hardening.** Every service runs with
  `security_opt: no-new-privileges:true` (no privilege escalation via
  setuid binaries even if a process escapes its initial capability
  set). Infrastructure containers (the reverse proxy, databases,
  caches, backups) drop every Linux capability and add back only what
  their entrypoints need (bind :80/:443, chown a data directory, drop to
  the service user). Application containers keep the default capability
  set: upstream images assume it, and a wrong guess there is a boot loop
  in production, not a hardening win. CI boots the stack under these
  settings on every push.

## [1.2.0] - 2026-09-02

### Added

- **Resource limits on every service, as `.env`-overridable defaults.**
  Each service now carries memory and CPU limits plus reservations
  (`<SERVICE>_MEMORY_LIMIT`, `_CPU_LIMIT`, `_MEMORY_RESERVATION`,
  `_CPU_RESERVATION`, defaults listed in `.env.example`). Set any of
  them in `.env` and the override survives every `git pull`. The
  defaults are what CI boots the stack under, so they are known to be
  enough for a fresh install; raise a limit if a service is OOM-killed
  under your real load (`docker inspect` shows `OOMKilled=true`).

## [1.1.1] - 2026-09-02

### Fixed

- `tests/e2e-backup-restore.sh` hardened against what the first CI runs
  across the fleet surfaced: no `grep -q` on a `docker logs` pipe (with
  `pipefail`, grep exiting early failed the whole pipeline on long
  logs); the dump content check scans the whole dump instead of its
  first 80 lines; content and restore are judged on a backup taken
  after the marker exists; containers are resolved through
  `docker compose ps -q` so a `container_name` override cannot break
  the lookup; the fake-old prune file uses `touch -t`, which BusyBox
  accepts.

## [1.1.0] - 2026-09-02

### Fixed

- **A file changing while the data archive is written no longer marks
  the backup as failed.** GNU `tar` exits 1 when a live application
  touched a file mid-read; the archive is complete and usable. The loop
  now treats exit 1 as success (noting it in the log line) and only a
  real `tar` failure (exit 2) produces `FAILED`. CI's archive check now
  reads the file name from the `backup OK` log line instead of racing an
  archive that may still be being written.

### Added

- **`tests/e2e-backup-restore.sh`** — seven end-to-end scenarios against
  the live stack, run by CI on every push and by you locally: the
  required-variable guard fires, a backup is produced, it is a readable
  archive with real dump content (and a readable data `tar.gz` where the
  stack has one), a database outage is reported as `FAILED`, **restore
  genuinely replaces database state** (a marker row inserted after the
  baseline backup is gone after restoring it), and pruning removes only
  old files.

### Fixed

- **A failed database dump no longer produces a silent, corrupt backup.**
  The old loop piped the dump into `gzip` and only checked `gzip`'s exit
  status, so a dump that failed halfway (database down, wrong password,
  disk full) still left a small `.gz` that looked like a backup. The loop
  now runs with `pipefail`, logs `Database backup OK: <file> (<bytes>
  bytes)` or `Database backup FAILED` per cycle, keeps a failed dump as
  `<file>.failed` for diagnosis, and prunes only its own files. Retention
  set to `0` disables pruning instead of deleting everything.

### Added

- CI now waits for the first backup cycle and proves the produced
  archive is readable and contains a real dump header (plus a readable
  `tar.gz` for the data backup where the stack has one).

## [1.0.0] - 2026-08-31

First semver release. Brings this template to the fleet standard established
in [keycloak-traefik-letsencrypt-docker-compose](https://github.com/heyvaldemar/keycloak-traefik-letsencrypt-docker-compose)
v1.2.0.

### Security

- **Jira bumped 9.11 → 11.3.10** (the 9.x line is long out of support).
  ❗ Existing deployments must follow Atlassian's upgrade path (via the
  10.3 LTS stop) — see the README. **Traefik bumped 3.2 → 3.7** (3.2's
  Docker client cannot talk to Docker Engine 29).
- **All three images pinned by `tag@sha256:digest`** (`postgres:15`
  digest-pinned; major unchanged so existing data dirs keep working).
- **Credentials untracked from git.** The tracked `.env` carried a
  generated-looking database password published on GitHub — rotate it if
  reused. `.env` is now gitignored; compose fails fast on unset values.

### Changed

- **Image pins live in the compose file as interpolation defaults**
  (`x-images` block); `.env` carries only secrets, hostnames, and
  deliberate overrides. Backup-loop variables escaped (`$$VAR`).
- README rebuilt to the fleet evaluator-first structure.

### Added

- **Deployment Verification workflow**: shellcheck + actionlint; Trivy
  scans of all three pinned images; weekly `check-pin-freshness` (digest
  drift + Jira Docker Hub tag lag + Traefik release lag); deploy-and-test
  that boots Jira with ephemeral credentials and requires `/status` to
  report FIRST_SETUP through Traefik.

### Fixed

- Shellcheck findings in both restore scripts.

[Unreleased]: https://github.com/heyvaldemar/jira-traefik-letsencrypt-docker-compose/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/heyvaldemar/jira-traefik-letsencrypt-docker-compose/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/heyvaldemar/jira-traefik-letsencrypt-docker-compose/compare/v1.1.1...v1.2.0
[1.1.1]: https://github.com/heyvaldemar/jira-traefik-letsencrypt-docker-compose/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/heyvaldemar/jira-traefik-letsencrypt-docker-compose/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/heyvaldemar/jira-traefik-letsencrypt-docker-compose/releases/tag/v1.0.0
