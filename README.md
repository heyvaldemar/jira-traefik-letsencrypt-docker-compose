# Jira + Traefik + Let's Encrypt — Docker Compose

[![Deployment Verification](https://github.com/heyvaldemar/jira-traefik-letsencrypt-docker-compose/actions/workflows/deployment-verification.yml/badge.svg?branch=main)](https://github.com/heyvaldemar/jira-traefik-letsencrypt-docker-compose/actions/workflows/deployment-verification.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Contents

- [Why this stack?](#why-this-stack)
- [Prerequisites](#prerequisites)
- [Getting started](#getting-started)
- [Features](#features)
- [Supply chain trust](#supply-chain-trust)
- [Production checklist](#production-checklist)
- [Backups](#backups)
- [Testing](#testing)
- [Security Notes](#security-notes)
- [About the maintainer](#about-the-maintainer)

This repository deploys **Jira Software (Data Center)** behind **Traefik** with automatic **Let's Encrypt TLS**, backed by **PostgreSQL**, with scheduled **backups** (database + application data) and companion **restore scripts**. One `docker compose up` away from issue tracking at `https://your-domain`.

📙 Full narrative installation guide on the blog: [heyvaldemar.com/install-jira-using-docker-compose/](https://www.heyvaldemar.com/install-jira-using-docker-compose/).

⚖️ **Licensing note:** Jira Data Center requires an Atlassian license (trials available). This template handles the infrastructure; the license is between you and Atlassian.

## Why this stack?

| Need | This stack | Manual install | Kubernetes | Other compose examples |
|------|-----------|----------------|------------|------------------------|
| Ready to deploy in <15 min | ✅ | ❌ | ✅ if K8s is already running | Often |
| TLS via Let's Encrypt, auto-renewed | ✅ Traefik ACME built-in | Manual certbot | Via cert-manager | Rare |
| External PostgreSQL wired with healthchecks | ✅ | Manual | ✅ | Varies |
| Scheduled DB + data backups + pruning | ✅ | Manual cron | External | Rare |
| Restore scripts included | ✅ two scripts | Manual | Manual | Rare |
| Upstream images pinned by `sha256` digest | ✅ | N/A | Depends | Rare |
| Weekly pin-freshness check in CI | ✅ | N/A | Depends | Rare |
| CI-verified deployment on every push | ✅ /status answers | N/A | Varies | Rare |
| Credentials via env (never committed) | ✅ | N/A | K8s Secrets | Often committed plaintext |

Four moving parts (Traefik + Jira + Postgres + backups). No Kubernetes prerequisites, no manual certificate management.

## Prerequisites

- **A Linux server** with a public IP and **RAM for the JVM** — defaults are 4 GB min / 8 GB max heap; the host wants 8–12 GB total.
- **Docker Engine 24+ and Docker Compose 2.20+.**
- **A domain you control,** with two `A` records pointing at your server's public IP — one for Jira, one for the Traefik dashboard. DNS must propagate before deploy.
- **Ports 80 and 443 open** on the server's firewall.
- **Disk for attachments, indexes, and backups.**

## Getting started

```bash
# 1. Clone
git clone https://github.com/heyvaldemar/jira-traefik-letsencrypt-docker-compose
cd jira-traefik-letsencrypt-docker-compose

# 2. Create the two Docker networks the stack expects
docker network create traefik-network
docker network create jira-network

# 3. Copy the environment template and fill in required values
cp .env.example .env
$EDITOR .env
# ^ Required: JIRA_DB_PASSWORD, JIRA_HOSTNAME, JIRA_URL,
#   TRAEFIK_HOSTNAME, TRAEFIK_ACME_EMAIL, TRAEFIK_BASIC_AUTH.

# 4. Deploy
docker compose -f jira-traefik-letsencrypt-docker-compose.yml -p jira up -d
```

First boot takes a few minutes (JVM + index initialization). Then `https://${JIRA_HOSTNAME}` serves the setup wizard — choose "I'll set it up myself", point it at the bundled database (host `postgres`, database `jiradb`, user `jiradbuser`, your `JIRA_DB_PASSWORD`), and follow the license step.

### What success looks like

```bash
# Services healthy:
docker compose -f jira-traefik-letsencrypt-docker-compose.yml -p jira ps

# Jira status endpoint (FIRST_SETUP before the wizard, RUNNING after):
curl -fsS "https://${JIRA_HOSTNAME}/status"
# Expected: {"state":"FIRST_SETUP"}

# Traefik issued a certificate:
docker compose -p jira logs traefik | grep -i "adding certificate"

# First backup lands after BACKUP_INIT_SLEEP (default 30m):
docker compose -p jira logs backups | tail -3
```

### Common first-deploy issues

- **Cert issuance fails.** DNS hasn't propagated or port 80 isn't reachable from the internet.
- **`docker compose up` fails with `set in .env`.** A required variable is empty; the error names it.
- **`network jira-network not found`.** Step 2 was skipped.
- **OOM-killed container.** Lower `JIRA_JVM_MINIMUM_MEMORY`/`JIRA_JVM_MAXIMUM_MEMORY` in `.env` to fit your host, or add RAM.

### Apply `.env` or compose-file changes

```bash
docker compose -f jira-traefik-letsencrypt-docker-compose.yml -p jira up -d --force-recreate
```

## Features

- **Jira Software Data Center** 11.3 line with an external **PostgreSQL 15** (not the evaluation H2), healthchecked and backupable.
- **Traefik v3** with automatic HTTP→HTTPS redirect and Let's Encrypt TLS-ALPN certificate issuance.
- **Basic-auth protected Traefik dashboard** on a separate hostname.
- **Tunable JVM heap** via `JIRA_JVM_MINIMUM_MEMORY` / `JIRA_JVM_MAXIMUM_MEMORY`.
- **Scheduled backups** of the database (`pg_dump | gzip`) and application data (`tar.gz`) with retention pruning, plus restore scripts for both.
- **Credentials required at deploy time** — compose fails fast if `.env` is incomplete.

## Supply chain trust

This repository is a **deployment template**, not a custom Docker image. It orchestrates three upstream images:

- [`traefik`](https://hub.docker.com/_/traefik) — reverse proxy, Docker Hub official image
- [`atlassian/jira-software`](https://hub.docker.com/r/atlassian/jira-software) — Jira upstream
- [`postgres`](https://hub.docker.com/_/postgres) — PostgreSQL, Docker Hub official image

All three are pinned to `tag@sha256:<digest>` as interpolation defaults in the compose file's `x-images` block — `git pull` alone delivers the version combination this repository has tested; an `*_IMAGE_TAG` variable in `.env` overrides the default deliberately.

The weekly `check-pin-freshness` CI job re-resolves each pinned tag against its registry, compares the pinned Jira version against the highest release tag on Docker Hub (Atlassian publishes no GitHub releases), and checks the Traefik minor against the latest upstream release. CI runs on every push, pull request, and every Monday at 06:00 UTC. GitHub Actions are pinned by commit SHA; Dependabot keeps those fresh.

## Production checklist

- [ ] **Strong secrets.** `JIRA_DB_PASSWORD` at 24+ random characters; regenerate the Traefik dashboard BCrypt hash per deployment.
- [ ] **Size the JVM to your instance** — Atlassian's sizing guides beat guesswork; defaults here suit a small team.
- [ ] **Host-mount the backup volumes** for disaster recovery.
- [ ] **Verify Let's Encrypt cert issuance** in the Traefik logs on first start.
- [ ] **Follow Atlassian's upgrade path for existing instances.** Moving from the previously pinned 9.11 to 11.x goes through the 10.3 LTS stop — back up, step through, verify. Fresh deployments start on 11.3 directly.
- [ ] **Know the restore procedure.** Run both restore scripts against a test environment before you need them.

## Backups

The `backups` container performs a dump → archive → prune → sleep loop: `pg_dump | gzip` of the Jira database, `tar.gz` of the application data (attachments, indexes), pruning by retention windows, then sleeping `BACKUP_INTERVAL` (default 24h). All knobs configured via `.env` with compose-level defaults.

Each cycle logs `Database backup OK: <file> (<bytes> bytes)` or `Database backup FAILED` (the same for the data archive where there is one). A failed dump is kept as `<file>.failed` for diagnosis and never overwrites a good backup — grep the log for `FAILED` from your monitoring.

**Verify backups are running:**

```bash
docker compose -p jira logs backups | tail -5
```

**Restore** with the interactive scripts (`chmod +x *.sh` once): `./jira-restore-database.sh`, then `./jira-restore-application-data.sh`.

## Resource limits

Every service carries memory and CPU limits plus reservations as compose-level defaults — the same values CI boots the stack under. Override any of them in `.env` (the knobs and their defaults are listed in `.env.example`, e.g. `TRAEFIK_MEMORY_LIMIT=512m`) and the override survives every `git pull`. If a service is OOM-killed under real load, `docker inspect <container> --format '{{.State.OOMKilled}}'` says so; raise its `_MEMORY_LIMIT` and recreate.

## Testing

The [Deployment Verification](https://github.com/heyvaldemar/jira-traefik-letsencrypt-docker-compose/actions/workflows/deployment-verification.yml?query=branch%3Amain) workflow runs on every push, pull request, and every Monday at 06:00 UTC:

1. **Lint** — shellcheck on both restore scripts, actionlint on the workflow.
2. **Trivy scans** of all three pinned images (CRITICAL/HIGH, SARIF to the Security tab).
3. **Pin freshness** (weekly/manual) — digest drift, Jira Docker Hub tag lag, Traefik release lag.
4. **Deploy-and-test** — boots the full stack with ephemeral credentials and requires `/status` to report `FIRST_SETUP` through Traefik — the shipped configuration must produce a serving Jira, not just started containers.

A green run is the authoritative proof that the template deploys end-to-end and that its backups restore.

### Backup and restore, proven

`tests/e2e-backup-restore.sh` runs against the live stack and is what CI executes after the HTTPS smoke. The scenario that matters most is the restore roundtrip: insert a marker row, restore the earliest backup, assert the marker is gone — a backup that cannot be restored fails the build. Run it yourself against a running deployment with short intervals in `.env` (`BACKUP_INIT_SLEEP=15s`, `BACKUP_INTERVAL=60s`):

```bash
chmod +x tests/e2e-backup-restore.sh
./tests/e2e-backup-restore.sh
```

It stops the database container briefly to prove failure detection — run it on a staging copy, not on production.

## Security Notes

- Credentials are read from `.env` at deploy time; `.env` is gitignored and compose fails fast on missing required variables.
- **Pre-rotation advisory.** Releases before v1.0.0 (2026-08-31) shipped a tracked `.env` with a generated-looking database password. Rotate `JIRA_DB_PASSWORD` if your deployment reused it.
- The database listens only on the internal network.
- Upstream image digests are pinned; the weekly freshness job flags drift loudly.

---

## About the maintainer

<div align="center">

**Maintained by [Vladimir Mikhalev](https://github.com/heyvaldemar)** — Docker Captain · IBM Champion · AWS Community Builder

[YouTube](https://www.youtube.com/channel/UCf85kQ0u1sYTTTyKVpxrlyQ?sub_confirmation=1) · [Blog](https://heyvaldemar.com) · [LinkedIn](https://www.linkedin.com/in/heyvaldemar/)

</div>
