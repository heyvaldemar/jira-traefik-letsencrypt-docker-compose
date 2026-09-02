# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

_(no unreleased changes yet)_

## [1.1.0] - 2026-09-02

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

[Unreleased]: https://github.com/heyvaldemar/jira-traefik-letsencrypt-docker-compose/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/heyvaldemar/jira-traefik-letsencrypt-docker-compose/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/heyvaldemar/jira-traefik-letsencrypt-docker-compose/releases/tag/v1.0.0
