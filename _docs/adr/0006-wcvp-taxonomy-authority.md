# 6. WCVP is the taxonomic authority; Catalogue of Life XR is the crosswalk to GBIF

Date: 2026-10-14

## Status

Accepted

## Context

Every occurrence, trait and habitat profile references a taxon, so one source has to decide which names are accepted. Three were available for plants:

- The GBIF Backbone. Its last rebuild was on 2023-08-28 and it will not be updated again. Building on it would freeze the taxonomy at that date, with no species described since and no later revisions.
- The Catalogue of Life eXtended Release (COL XR). GBIF now matches occurrence records against it by default, so GBIF occurrences arrive carrying COL identifiers. It is rebuilt monthly. Its usage keys are alphanumeric (`8VTYD`), not integers.
- The World Checklist of Vascular Plants (WCVP), Kew's expert-curated list, also published through Plants of the World Online (POWO). It carries accepted names, synonyms, unplaced names, authorship, basionym links and a lifeform field.

## Decision

WCVP is the authority for plants. Each WCVP release mints PKI taxa and sets their accepted names; `taxa.source_id` records which release.

COL XR is the crosswalk. Its name usages are matched onto taxa that WCVP has already minted, through `taxon_identifiers`, which is how GBIF occurrences find their PKI taxon. COL never mints a taxon or changes an accepted name.

Exported taxon records use the PKI taxon ID, as a resolvable HTTPS URI, for Darwin Core `taxonID`, `acceptedNameUsageID` and `parentNameUsageID`. A PKI ID is never re-minted, so it stays persistent across WCVP and COL releases, as FAIR principle F1 (globally unique, persistent identifiers) requires. `scientificNameID` is the IPNI (International Plant Names Index) ID and `nameAccordingTo` is the WCVP release. COL, WCVP, IPNI and POWO IDs are exported as identifiers from `taxon_identifiers` (R10).

When WCVP and COL disagree on an accepted name, WCVP wins. The disagreement is stored in the `taxon_crosschecks` dbt model and shown on the species page; it is never resolved automatically.

The authority is chosen per kingdom through `taxa.source_id`. WCVP covers plants only; another kingdom would need its own authority and its own ADR.

## Consequences

- Accepted names follow Kew's curation and change only when a new WCVP release is loaded.
- Two sources must be versioned and recorded in `sources`: each WCVP release and each COL XR release.
- Matching COL to WCVP is a join only if COL XR carries WCVP IDs in its source-ID field. If it does not, Kew's fuzzy matcher (rWCVP) is needed. This is checked on the first COL pull (#18).
- COL usages that match no WCVP taxon are listed as unresolved, not minted (#19).
- Every exported taxon has a `taxonID`, including those with no COL match. GBIF users join to COL through the exported identifiers, not directly on `taxonID`.
- The `taxonID` URI must resolve, so it depends on the public domain and the API's taxon route (#38).
- A new WCVP release can rename, merge or split taxa. How those changes are recorded is ADR 0007.
