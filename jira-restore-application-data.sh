#!/usr/bin/env bash
# jira-restore-application-data.sh [backup-file-name]
#
# Replaces Jira's application data with one of the archives the backups
# service wrote.
#
#   ./jira-restore-application-data.sh               list and ask
#   ./jira-restore-application-data.sh <file-name>   restore that one
#
# EVERY PATH, NAME AND CREDENTIAL COMES FROM THE RUNNING BACKUPS CONTAINER.
# The previous version carried the backup directory and data path as
# literals, found its containers with a name filter that misses them under any
# -p but the default, and cleared the data with rm -rf dir/*, which leaves
# every dotfile of the newer state in place. It also ran docker exec -it,
# which refuses to start without a terminal.
# The backup loop reads its own environment, so this reads the same one, and
# the two cannot disagree.
#
# CI runs this exact file against a marker written after the backup it
# restores, and requires the marker to be gone.
#
# Set COMPOSE_PROJECT_NAME if the stack was started with a -p other than jira.
set -Eeuo pipefail

PROJECT="${COMPOSE_PROJECT_NAME:-jira}"
APP_SERVICE="jira"

cid() {  # the container of one compose service in this project
  docker ps -aq --filter "label=com.docker.compose.project=$PROJECT" \
    --filter "label=com.docker.compose.service=$1" | head -n 1
}
APP="$(cid "$APP_SERVICE")"; BKP="$(cid backups)"
[ -n "$BKP" ] || { echo "error: no backups container in compose project '$PROJECT' (set COMPOSE_PROJECT_NAME)" >&2; exit 1; }
[ -n "$APP" ] || { echo "error: no $APP_SERVICE container in compose project '$PROJECT'" >&2; exit 1; }
[ "$(docker inspect -f '{{.State.Running}}' "$BKP")" = true ] || { echo "error: the backups container is not running" >&2; exit 1; }

env_of() { docker exec "$BKP" printenv "$1"; }
DIR="$(env_of DATA_BACKUPS_PATH)"; NAME="$(env_of DATA_BACKUP_NAME)"; DATA="$(env_of DATA_PATH)"
case "$DATA" in ""|/) echo "error: DATA_PATH is '$DATA'; refusing to clear it" >&2; exit 1 ;; esac

SELECTED="${1:-}"
if [ -z "$SELECTED" ]; then
  echo "Application data backups in $DIR:"
  docker exec "$BKP" sh -c "ls -1 '$DIR' | grep -E '^$NAME-.*\\.tar\\.gz\$'" || { echo "  none found" >&2; exit 1; }
  read -r -p "File name to restore: " SELECTED
fi
case "$SELECTED" in ""|*/*) echo "error: give a file name from the list, not a path" >&2; exit 1 ;; esac
docker exec "$BKP" tar -tzf "$DIR/$SELECTED" >/dev/null \
  || { echo "error: $DIR/$SELECTED is missing or does not open; nothing was changed" >&2; exit 1; }

echo "Stopping $APP_SERVICE so nothing writes while its data is replaced"
docker stop "$APP" >/dev/null
restart() { docker start "$APP" >/dev/null && echo "Started $APP_SERVICE"; }
trap 'restart' EXIT
echo "Restoring $SELECTED"
# The archive holds the data directory relative to / (the loop writes it that
# way), so it is extracted at /; what was there first is removed so files that
# did not exist at backup time do not survive the restore.
if ! docker exec "$BKP" sh -c "set -eu
    find '$DATA' -mindepth 1 -delete
    tar -xzpf '$DIR/$SELECTED' -C /"; then
  echo "error: the restore failed part-way; $DATA may be incomplete. Restore another archive before using Jira." >&2
  exit 1
fi
echo "Restored $SELECTED into $DATA"
