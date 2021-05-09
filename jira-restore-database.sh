#!/bin/bash

JIRA_CONTAINER=$(docker ps -aqf "name=jira_jira")
JIRA_BACKUPS_CONTAINER=$(docker ps -aqf "name=jira_backups")

echo "--> All available database backups:"

for entry in $(docker container exec -it $JIRA_BACKUPS_CONTAINER sh -c "ls /srv/jira-postgres/backups/")
do
  echo "$entry"
done

echo "--> Copy and paste the backup name from the list above to restore database and press [ENTER]
--> Example: jira-postgres-backup-YYYY-MM-DD_hh-mm.gz"
echo -n "--> "

read SELECTED_DATABASE_BACKUP

echo "--> $SELECTED_DATABASE_BACKUP was selected"

echo "--> Stopping service..."
docker stop $JIRA_CONTAINER

echo "--> Restoring database..."
docker exec -it $JIRA_BACKUPS_CONTAINER sh -c 'PGPASSWORD="$(echo $POSTGRES_PASSWORD)" dropdb -h postgres -p 5432 jiradb -U jiradbuser \
&& PGPASSWORD="$(echo $POSTGRES_PASSWORD)" createdb -h postgres -p 5432 jiradb -U jiradbuser \
&& PGPASSWORD="$(echo $POSTGRES_PASSWORD)" gunzip -c /srv/jira-postgres/backups/'$SELECTED_DATABASE_BACKUP' | PGPASSWORD=$(echo $POSTGRES_PASSWORD) psql -h postgres -p 5432 jiradb -U jiradbuser'
echo "--> Database recovery completed..."

echo "--> Starting service..."
docker start $JIRA_CONTAINER
