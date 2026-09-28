# 2. Names and settings live in `.env`; secrets follow a naming rule

Date: 2026-09-27

## Status

Accepted

## Context

The stack needs database names, role names, a bucket name, admin user names, a domain and a host port, as well as secrets. These could be fixed in `docker-compose.yml` and scripts, or set in `infra/.env`.

Several of them only take effect once. Postgres names and passwords are applied when the data volume is first created, and lakeFS creates its admin user only when its metadata store is empty.

## Decision

Every name and environment-specific setting is a variable in `infra/.env`, documented in `infra/.env.example`. Nothing hardcodes a role, database, bucket, user name or domain: scripts read them from the container environment, and services receive them through Compose substitution written as `${VAR:?}`, so Compose refuses to start when one is missing or empty.

Every secret's name ends in `_PASSWORD` or `_KEY`, and those suffixes are used only for secrets. The header of `.env.example` states the rule, so no per-line marker is needed.

## Consequences

- One file describes an environment. The local machine and the production server differ only in `.env` values.
- Values applied only on first start are marked in `.env.example`. Changing them later requires recreating the volume (`just reset`), which deletes that data.
- Adding a secret means naming it `*_PASSWORD` or `*_KEY`, adding it to `.env.example`, and declaring it as a Compose secret (ADR 0001).
