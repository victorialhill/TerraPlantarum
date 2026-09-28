# 4. Operator tools and the database are private-only, with one configuration everywhere

Date: 2026-09-27

## Status

Accepted. Changes the build plan's issue #43, which had lakeFS and Dagster public.

## Context

The stack serves two audiences. End users need the species pages and the public API. Only the operator needs the lakeFS UI and API, the Dagster UI, the SeaweedFS admin UI and Postgres, and these can change or delete data. Exposing them publicly leaves each tool's own login as the only protection, which is what attackers scan for and what fails when a tool has an authentication bug.

The build plan also calls for hostnames and HTTPS through Caddy, and local development should behave like production.

## Decision

- Local and production use the same `docker-compose.yml` and `Caddyfile`. Only `.env` differs, notably `TERRAPLANTARUM_DOMAIN` (`localhost` locally).
- Every site is a hostname under that domain, served over HTTPS. Caddy uses its local CA for `*.localhost` and Let's Encrypt for real domains.
- Operator sites import the `private_only` snippet, which answers 403 to any address outside Caddy's `private_ranges`. Public sites (web, API) do not.
- Postgres is published only on `127.0.0.1` (`POSTGRES_HOST_PORT`). Services reach it over the Compose network; people reach it locally or through an SSH tunnel or VPN on the server.
- No other service publishes ports. Caddy is the only entry point.

## Consequences

- Operator tools are protected in production without any production-only configuration.
- Locally, the browser reaches Caddy from a private Docker address, so operator sites work as normal (verified on Docker Desktop for Windows).
- If a VPN such as Tailscale is used, its range (`100.64.0.0/10`) is not in `private_ranges` and must be added to the snippet.
- Each development machine trusts Caddy's local root certificate once. Deleting the `caddy-data` volume (`just reset`) creates a new CA, which must be trusted again.
- Windows `curl.exe` needs `--ssl-no-revoke` with Caddy's local CA, because the CA publishes no revocation information.
- That operator sites refuse public addresses can only be tested on the server, as part of #43.
