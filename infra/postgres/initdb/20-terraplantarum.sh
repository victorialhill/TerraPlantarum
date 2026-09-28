#!/usr/bin/env bash
# Creates the gold and Dagster databases and their roles.
# Runs once, when the postgres data volume is first created.
set -e
. /terraplantarum/read-secret.sh

tp_password="$(read_secret terraplantarum_db_password)"
api_password="$(read_secret terraplantarum_api_db_password)"
dagster_password="$(read_secret dagster_db_password)"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres \
    -v tp_db="$TERRAPLANTARUM_DB_NAME" \
    -v tp_role="$TERRAPLANTARUM_DB_ROLE" \
    -v tp_password="$tp_password" \
    -v api_role="$TERRAPLANTARUM_API_DB_ROLE" \
    -v api_password="$api_password" \
    -v dagster_db="$DAGSTER_DB_NAME" \
    -v dagster_role="$DAGSTER_DB_ROLE" \
    -v dagster_password="$dagster_password" \
    <<'EOSQL'
CREATE ROLE :"tp_role" LOGIN PASSWORD :'tp_password';
CREATE ROLE :"api_role" LOGIN PASSWORD :'api_password';
CREATE ROLE :"dagster_role" LOGIN PASSWORD :'dagster_password';

CREATE DATABASE :"tp_db" OWNER :"tp_role";
CREATE DATABASE :"dagster_db" OWNER :"dagster_role";

-- Only named roles may connect; by default every role can connect to every database.
REVOKE ALL ON DATABASE :"tp_db" FROM PUBLIC;
REVOKE ALL ON DATABASE :"dagster_db" FROM PUBLIC;
GRANT CONNECT ON DATABASE :"tp_db" TO :"api_role";

\connect :"tp_db"
CREATE EXTENSION IF NOT EXISTS postgis;

-- Whatever dbt (tp_role) creates later is readable by the API, in any schema.
ALTER DEFAULT PRIVILEGES FOR ROLE :"tp_role" GRANT USAGE ON SCHEMAS TO :"api_role";
ALTER DEFAULT PRIVILEGES FOR ROLE :"tp_role" GRANT SELECT ON TABLES TO :"api_role";
EOSQL
