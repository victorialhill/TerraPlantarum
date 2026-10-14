# 11. Occurrences are assigned to concepts by recorded evidence, never by habitat

Date: 2026-10-14

## Status

Accepted

## Context

When WCVP splits a species, ADR 0007 records how the concepts relate, but each occurrence record still has to be placed in one of the new concepts. Usually the old name stays with the part containing its type specimen, so a split of D gives a narrow D and a new species E.

GBIF does not do this placement. It matches each record's name against its current taxonomy, so after a split every record named D is filed under the narrow D, including records collected from plants that are now E. A record moves only when its publisher re-identifies it.

iNaturalist does place its own observations: one inside the range of exactly one new species moves to it, and the rest move to the common ancestor, which removes them from GBIF until someone re-identifies them. iNaturalist supplies 7,490 of the 130,961 georeferenced Anthurium records in GBIF (6%, measured 2026-10-14). The remaining 94% are mostly herbarium specimens (114,808) that no one re-places after a split.

The evidence available on those records, measured on Anthurium in GBIF on 2026-10-14:

- 23,386 of 186,857 records (12.5%) carry the Darwin Core identification history extension, which lists every identification with its date.
- 30–50% of specimens and about 58% of human observations carry `dateIdentified`, in two non-random samples.
- 47 records come from Plazi, which extracts specimen citations from published papers.
- WCVP records each species' distribution by WGSRPD level 3 region, which is roughly a country. 62% of records come from Colombia, Ecuador, Brazil and Costa Rica.

Placing records by climate or elevation would be circular: habitat would decide the species, and the species' habitat would then be computed from those records.

## Decision

After a split, each occurrence is assigned to a new concept by the first of these that applies, and the evidence used is stored on the record:

1. `type_specimen`: the record is a type specimen of one of the new concepts.
2. `revision_citation`: the specimen is cited for one new concept in the published revision. Citations are entered as a versioned CSV in the repository, one file per revision, only when someone chooses to transcribe them.
3. `redetermined`: the record's identification history or `dateIdentified` shows it was identified as one of the new concepts after the revision was published.
4. `distribution`: the record lies in a WGSRPD level 3 region where WCVP lists only one of the new concepts as native.

A record that none of these place stays with the broad, pre-split concept, with `assignment_basis = unassigned`. Climate, elevation and any other habitat value are never used.

## Consequences

- Narrow-concept profiles are computed only from records with evidence. The broad concept keeps the unassigned records and its own profile, marked as replaced (ADR 0007).
- Every assignment can be audited from the stored basis, and the methods write-up (#50) can report how many records each basis placed.
- A dbt model, `split_review_queue`, lists the records a person should check: every `unassigned` record from a split, and `distribution` records whose coordinate uncertainty reaches a second WGSRPD region or whose region WCVP lists as doubtful or introduced for that species. Records with images come first, grouped by split. Confidence is derived from `assignment_basis` and these checks, so no extra column is stored. Nothing waits on the list.
- Where a person's decisions on reviewed records are stored is a separate decision, made when someone starts reviewing. A CSV in the same form as the revision citations is the expected fit.
- Within-country splits will often leave most records unassigned, because WCVP regions are about country-sized.
- `occurrences` needs `date_identified` and `assignment_basis`, and GBIF downloads must include the identification history extension. R9 lists `dateIdentified` and `identifiedBy`.
- National floras with finer distribution data (Brazil, Colombia, Ecuador) can be added as distribution sources once their licenses and access are checked (#13).
- The same evidence order applies to literature and contributor records in Phases 2 and 3, which carry less evidence and will be unassigned more often.
- iNaturalist records arrive already placed by iNaturalist's own split process, so they go through the same steps and usually resolve at step 3.
