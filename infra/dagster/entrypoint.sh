#!/bin/sh
# Loads the Dagster database password from its Compose secret, then runs the given command
# dagster.yaml reads the password only from an environment variable, not from the secret file
# Shared by dagster-webserver, dagster-daemon and pipeline, whose runs write to the same storage
set -e
. /terraplantarum/read-secret.sh

DAGSTER_DB_PASSWORD="$(read_secret dagster_db_password)"

export DAGSTER_DB_PASSWORD
exec "$@"
