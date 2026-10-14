# 10. The API reads gold through EF Core keyless entities

Date: 2026-10-14

## Status

Accepted

## Context

The API (.NET 10) serves taxa and habitat profiles from the gold database. dbt builds and owns every gold object (ADR 0005), and the API connects as a read-only role that cannot create objects. Gold holds PostGIS geometry.

The queries behind a profile (aggregation, roll-ups of infraspecific taxa, following concept relations per ADR 0007) can live in the API's code or in dbt models. In dbt they are versioned, tested SQL that runs in the same lakeFS-committed pipeline as everything else, so their results carry the same provenance.

Phase 3 adds write endpoints, which need change tracking and transactions.

## Decision

The API uses EF Core with the Npgsql provider. Gold materialized views are mapped as keyless entity types (entity types with no primary key), and geometry is mapped with Npgsql's NetTopologySuite plugin. Database names follow the snake_case convention.

Complex queries stay in dbt views. The API only issues simple selects against them, so every number it serves was computed by the pipeline and traces to a run.

EF Core migrations never create or change gold objects. If the Phase 3 write endpoints need API-owned tables, that is a separate decision.

## Consequences

- One data-access library covers today's read-only views and Phase 3's writes.
- Changing a view's columns means changing the dbt model and the matching entity type together. Nothing generates one from the other.
- Keyless entities cannot be tracked or updated, which matches the read-only role.
- The API cannot apply migrations at start-up, because its role cannot create objects (ADR 0005).
