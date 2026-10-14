# 7. Taxon changes are recorded as TCS concept relations

Date: 2026-10-14

## Status

Accepted

## Context

A PKI taxon ID is permanent and never re-minted (ADR 0006). Occurrences, observations and habitat profiles reference it, and exports publish it as `taxonID`. Each WCVP release can change a name's circumscription (which plants the name covers): a species is renamed, two species are merged, or one is split into several.

The options were:

- Overwrite the taxon when its circumscription changes. Its history is lost, and an ID cited from an earlier release silently means something different.
- Key taxa by name. A rename then changes the ID, and one name used for two different concepts cannot be told apart.
- Keep each concept as its own taxon and record how concepts relate, using the TDWG Taxon Concept Schema (TCS). TCS relates two concepts with one of the five RCC-5 relations: congruent, includes, included in, overlaps, excludes.

## Decision

Concept changes are recorded in `taxon_concept_relations`, one row per relation: from taxon, to taxon, relation, `according_to` (the `sources` row of the WCVP release that made the change), `basis`, `reference`, and `run_id`. `relation` is one of the five RCC-5 values. `basis` is `release_diff` when the row was inferred by comparing two WCVP releases; `asserted` is reserved for relations entered by a person. `reference` is the published revision behind the change, as a DOI where one exists.

Rows are written automatically by diffing accepted names between two WCVP releases, and follow WCVP's judgement without review:

- Rename: the concept is congruent. The taxon keeps its ID and only its accepted name changes; no new taxon is minted.
- Merge: a new taxon is minted, and each old taxon gets an `included_in` row pointing to it.
- Split: new taxa are minted, each with an `included_in` row pointing to the old taxon. Which new taxon each occurrence belongs to is decided by ADR 0011.

Gold views follow relations to the current concept. Exports map each row to a TCS TaxonConceptMapping: subject and object concept, RCC-5 relationship, and `accordingTo`.

A replaced concept keeps its taxon ID and its observations, so its habitat profile stays available. `habitat_profiles` and the API mark it as replaced and name the current concept.

The API answers a request for a replaced taxon ID with that taxon's record, the current concept, and the relation between them, and never with not-found (#38).

## Consequences

- An ID cited from any earlier release still resolves, and leads to its current concept through the relations.
- A profile cited from an earlier release can still be read, and is labelled with the concept that replaced it.
- Growers holding a plant under an old name reach the current species through synonyms in `taxon_names` and through the relations.
- The table is empty after the first WCVP load. It fills only once a second release is loaded.
- Only renames, merges and splits are written. `includes`, `overlaps` and `excludes` are valid values, but nothing writes them in Phase 1.1. Entering relations by hand (`basis = asserted`) is a separate decision, which would also add who asserted each row and when.
- Some splits recorded as `included_in` may really be overlaps, where members also move between the new species. Comparing names cannot detect this.
- A wrong automatic merge loses nothing: the old taxa keep their IDs and profiles, and the relation can be corrected.
- The release diff (#23) is tested with two historical WCVP releases, and can slip to Phase 1.2 without blocking anything else.
