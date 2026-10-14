# 8. CHELSA is the only climate source in Phase 1.1

Date: 2026-10-14

## Status

Accepted

## Context

Habitat profiles need climate values sampled at every cleaned Anthurium occurrence (R5). Anthurium is concentrated in Andean cloud forest, where elevation and therefore temperature and rainfall change over short distances.

The two common global gridded climate sources are:

- WorldClim, which interpolates between weather stations. Stations are sparse in the Andes, so interpolation is weakest exactly where Anthurium lives.
- CHELSA, which downscales climate model output using terrain, including orographic effects (mountains forcing air upward, which raises rainfall on windward slopes). It is licensed CC0.

Comparing two climate sources would show how much a profile depends on the source, but it doubles the sampling, storage and provenance work before the first profile exists.

## Decision

Phase 1.1 uses CHELSA alone, bioclimatic variables bio1–bio19. Each CHELSA version is recorded as a `sources` row, downloaded with checksums (#31), and sampled at every surviving occurrence with Rasterio (#32). Variables keep CHELSA's own codes (`chelsa_bio1`, R16).

WorldClim is added in Phase 1.2 as a comparison layer.

## Consequences

- Climate values come from one source, so a profile cannot yet show how sensitive it is to the choice of climate data.
- CC0 places no license condition on the output dataset.
- Variable names carry the source prefix, so adding WorldClim later adds variables and does not rename existing ones.
- Profiles are recomputed when the CHELSA version changes, and each run records which version it used (R19).
