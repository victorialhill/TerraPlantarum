# 9. Occurrence cleaning uses R's CoordinateCleaner in its own container

Date: 2026-10-14

## Status

Accepted

## Context

GBIF occurrences include records with bad coordinates: points at country or province centroids, capitals, biodiversity institutions such as herbaria and botanic gardens, zero or swapped coordinates, and points at sea. Each must be flagged by a documented, versioned rule, with counts per species of what entered and survived each rule (R4).

CoordinateCleaner is an R package that implements these tests. It ships curated reference data for them (institution coordinates, centroids, capitals) and is a published, citable method (Zizka et al. 2019, Methods in Ecology and Evolution).

The rest of the pipeline is Python. Reimplementing the tests in Python would mean building and maintaining the reference data, and the method would no longer be the citable one.

## Decision

The CoordinateCleaner tests run in R, in the `clean-r` container: dependencies locked with renv (R's per-project lock file), launched once per run by Dagster through Dagster Pipes (Dagster's protocol for running an external process and collecting its logs and results), reading Parquet in and writing Parquet out, then exiting.

Rules that do not need CoordinateCleaner (absence records, cultivated or captive records, missing coordinates, GBIF issue flags) run in Python. Every rule, from either language, is a versioned row in `cleaning_rules`, and every rule's result is a row in `occurrence_cleaning`.

## Consequences

- The methods write-up (#50) can cite CoordinateCleaner and its version, so the cleaning step is reviewable and repeatable by others.
- R is a fourth language stack. It needs its own image, lock file, `testthat` tests and CI job (#27).
- Parquet is the only interface between Python and R, so neither side imports the other's code.
- Changing a rule or upgrading CoordinateCleaner is a new rule version. Runs record which version they used (R19).
