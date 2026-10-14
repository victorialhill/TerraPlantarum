# 1. Secrets reach containers only as Compose secrets

Date: 2026-09-27

## Status

Accepted

## Context

The build plan asks for ".env.example naming every secret, and Compose secrets so nothing lands in Git." Values in `infra/.env` (gitignored) could be passed as plain environment variables, but those are visible to anyone who can run `docker inspect`.

Not every image can read a secret from a file:

- The postgres image reads `POSTGRES_PASSWORD_FILE`.
- lakeFS reads configuration only from `LAKEFS_*` variables or a config file.
- SeaweedFS `weed mini` reads S3 credentials only from `AWS_*` variables and signing keys from `WEED_JWT_*` variables. With no credentials it starts with anonymous access allowed.

## Decision

Every password and key reaches a container only as a Compose secret, mounted at `/run/secrets/<name>`. Each secret is declared in `docker-compose.yml` with `environment:` as its source, so `infra/.env` remains the single place values are set.

Where an image cannot read secret files, a small POSIX `sh` wrapper (`infra/<service>/entrypoint.sh`) reads the files, exports the variables the program expects inside its own process, and `exec`s the real entrypoint. The postgres init script reads its secrets the same way.

All of these use one shared function, `read_secret` in `infra/lib/read-secret.sh`, mounted read-only at `/terraplantarum/read-secret.sh`. It stops the calling script when a secret is missing or empty, so a service never starts with a blank credential.

Project files mounted into containers live under `/terraplantarum/`, apart from the postgres init script, which must be in `/docker-entrypoint-initdb.d/`.

## Consequences

- No secret appears in `docker inspect` or in a container's configured environment. Wrapper-exported variables exist only in the service's own process.
- A missing or empty secret stops start-up with an error that names the secret. Without this check, SeaweedFS would start unauthenticated and Postgres would create a role with an unusable password.
- A service must list a secret under its own `secrets:` to receive it; the top-level declaration alone is not enough.
- SeaweedFS's admin password can only be passed as a flag, so it is visible in `ps` inside that container, though not in `docker inspect`.
- A new service whose image cannot read secret files needs its own wrapper that loads `read-secret.sh`.
