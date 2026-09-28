# 5. Gold database roles: dbt owns, the API reads, Dagster is separate

Date: 2026-09-27

## Status

Accepted

## Context

One PostGIS server holds two databases: gold (`TERRAPLANTARUM_DB_NAME`) and Dagster's run history (`DAGSTER_DB_NAME`). The build plan says gold objects are owned by dbt (#12), and that the API uses EF Core keyless entities over them, so it only issues selects (#38). EF Core migrations do not build gold. If the Phase 3 write endpoints need API-owned tables, that is a separate decision.

By default Postgres lets every role connect to every database, and a superuser shared by all services could change anything.

## Decision

The init script (`infra/postgres/initdb/20-terraplantarum.sh`) runs once, on the first start of an empty volume, and creates:

- `TERRAPLANTARUM_DB_ROLE`, which owns the gold database and everything dbt creates in it.
- `TERRAPLANTARUM_API_DB_ROLE`, which can connect to gold and select from whatever the owner creates, in any schema, through `ALTER DEFAULT PRIVILEGES FOR ROLE <owner>`. It cannot create objects.
- `DAGSTER_DB_ROLE`, which owns the Dagster database and cannot connect to gold.

`CONNECT` is revoked from `PUBLIC` on both databases. PostGIS is created in the gold database.

## Consequences

- dbt dropping and recreating views does not lose the API's access, because the default privileges apply to every new object the owner creates.
- The smoke tests check that the owner can create, the API can read what the owner creates, the API cannot create, and Dagster cannot reach gold.
- Grants on objects created by any role other than the owner are not covered. dbt must connect as the owner role.
- Changing roles after the first start means a migration script, or recreating the volume in development (`just reset`).
