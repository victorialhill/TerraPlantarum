# PKI / Terra Plantarum — Phased Build Plan

Sep 23, 2026 · @Tori

## How to read this document

PKI builds in four phases, and Phase 1 is the Habitat Engine. Each phase below is described only at the level of what it must accomplish; the detailed breakdown of a phase (tasks, sources, tools, sequencing) gets added as that phase becomes current, so nothing is planned in detail further ahead than it needs to be.

The architecture spec's locked build order is taxonomy → observations schema → Habitat Engine → literature pipeline. Leading with the Habitat Engine keeps that order intact: Phase 1 carries the minimum taxonomy and observations scaffolding the engine needs to write into, rather than treating those as a separate phase.

## Phase 1 — Habitat Engine

**Goal:** for one genus, turn cleaned occurrence points into a confidence-scored native habitat profile per species, shown on a species page and published as a versioned, citable dataset.

**What it has to accomplish**

- A name-resolution backbone deep enough to key every record to an accepted taxon. Family-wide coverage is acceptable since it is cheap; habitat computation stays narrow.
- The observations schema finalized before the first habitat output is written. Habitat profiles are the first observations in the system, and retrofitting the schema later is the expensive mistake the architecture doc warns against.
- Occurrence cleaning and quality filtering. This is where most of the real effort goes.
- Environmental cross-referencing per occurrence point, with a settled answer to the epiphyte and hemiepiphyte question: what "habitat" means when the plant is not rooted in the ground.
- Aggregation into per-species profiles with honest uncertainty — ranges and confidence, never a bare number.
- A species page that displays the result, and a citable, versioned artifact of the demo output.

**Success looks like:** every species in the genus with at least one cleaned occurrence has a habitat profile, each value traceable to its occurrences, sources and pipeline run.

### Phase 1.1 — Decisions and scope

Phase 1.1 builds the end-to-end pipeline for a single genus and accepts that the epiphyte habitat problem is unsolved. The point is a working pipeline, not a finished habitat model.

- Genus: Anthurium, every species in it. Chosen for breadth, the MoBOT relationship, and because its Andean cloud-forest distribution is where climate data quality matters most.
- Both terrestrial and epiphytic/hemiepiphytic species go through the same pipeline. Soil data is collected for all of them, with the understanding that it is weakly meaningful for epiphytes.
- Every species carries a growth-habit field from the start, so epiphyte-specific handling can be layered on in Phase 1.2 without re-running ingestion.
- Output is per-species climate and soil profiles with confidence, written into the observations table as the first real observations. Every species with at least one cleaned occurrence record (a georeferenced GBIF record; "point" below means one of these) gets a profile, flagged low-confidence where the data is thin. A species with no usable points returns its taxon record and what raw data exists, but no computed profile.

### Phase 1.1 — Data sources

Four sources cover Phase 1.1. GBIF now uses the Catalogue of Life Extended Release as its default taxonomy, so keying occurrences to COL taxon IDs keeps taxonomy and occurrence data on the same identifiers ([GBIF data blog](https://data-blog.gbif.org/post/catalogue-of-life-taxonomic-backbone/), [GBIF tech docs](https://techdocs.gbif.org/en/data-processing/taxonomy-interpretation)).

| Layer | Source | Why | Alternative worth considering |
| --- | --- | --- | --- |
| Taxonomy | WCVP / POWO (authority) + Catalogue of Life XR (crosswalk) | GBIF's default taxonomy as of 2025; legacy GBIF backbone is frozen at 2023 | POWO as the botanical authority for accepted names and author citations; COL for IDs, POWO to cross-check |
| Occurrence | GBIF | Largest georeferenced record set; occurrences already matched to COL taxon keys | iDigBio for US herbarium records GBIF misses (defer to 1.2) |
| Soil | SoilGrids | Only global gridded soil chemistry at usable resolution | None at this scale; accept the epiphyte limitation |
| Climate | CHELSA (CC0) | Orographic downscaling handles the Andean cloud-forest terrain where Anthurium lives; WorldClim's station interpolation is weakest there | WorldClim added in 1.2 as a comparison layer |
| Growth habit | Zotz et al. (2021) epiphyte checklist + WCVP lifeform field | EpiList is the expert-curated epiphyte list; WCVP covers habit for non-epiphytes too. Disagreements stored, not resolved | EOL TraitBank, GIFT, TRY in 1.2 |

Sources deliberately left for Phase 1.2: WorldClim (comparison against CHELSA), iDigBio, EOL TraitBank, GIFT/TRY, the Anthurium sectional classification (no structured source exists; compile from Carlsen & Croat's published phylogeny as a PKI-maintained CSV with citations), canopy cover and cloud frequency (the epiphyte light and moisture environment), herbarium label text, and iNaturalist.

### Phase 1.1 — Stack

The pipeline follows medallion architecture. The architecture spec's Raw Input, Observations, and Computed zones are the bronze, silver, and gold tiers. Every tool below is free and self-hosted; PKI doubles as the data-engineering skills project, so tool choices favor what appears on real postings without adding infrastructure the data volume doesn't justify.

| Concern | Tool | Role in the pipeline |
| --- | --- | --- |
| File format | Parquet / GeoParquet | Every tier is Parquet; occurrences with coordinates are GeoParquet |
| Object storage | SeaweedFS | S3-compatible lake; bronze/silver/gold as bucket prefixes. Chosen over MinIO, whose open-source edition was archived in April 2026 and ships no maintained images |
| Lake versioning | lakeFS (open source) | Git-style branches and commits over the SeaweedFS bucket; re-run a cleaning rule on a branch, diff, merge or discard. Chosen over DVC because it is a storage layer, not file pointers |
| Query and transform | DuckDB (+ spatial extension) | Reads Parquet in place; bronze → silver transforms and raster sampling prep. Spark deliberately not used at this scale |
| Orchestration | Dagster | Asset-based model maps onto medallion tiers; each tier's tables are declared assets |
| SQL transforms | dbt Core | Silver → gold as versioned, tested SQL against DuckDB or Postgres |
| Data quality | Great Expectations (GX Core) | Tabular checks: nulls, ranges, uniqueness, row counts. Geospatial validity checks run in GeoPandas/DuckDB instead, since GX v1 does not yet support custom Expectations |
| Geospatial | GeoPandas, Rasterio | Occurrence cleaning, sampling CHELSA and SoilGrids rasters at coordinates |
| Serving | PostgreSQL + PostGIS | Gold tier and the API's database; occurrences as geometry columns, spatial queries in SQL, materialized views for computed profiles |
| Language | Python (pipeline), C#/.NET (API) | Unchanged from the architecture spec; they communicate through Postgres |

Deferred to Phase 2: a table format (Apache Iceberg or Delta Lake) over the Parquet lake, once there is enough write traffic to justify ACID and time travel.

**Languages and frameworks by component**

The rule for language choice: the best tool for the job, where "best" includes what a botanist reviewer would recognize as the reference implementation. R enters only where an R package is that reference and has no Python peer.

| Component | Language | Framework / libraries | Status |
| --- | --- | --- | --- |
| Ingestion (WCVP, COL, GBIF pulls) | Python | httpx for APIs, pygbif for GBIF downloads, pyarrow to write Parquet; uv for environments | Decided |
| WCVP ↔ COL name matching | Python (rWCVP if needed) | A join if COL XR carries WCVP IDs in its source-ID field — check on the first pull. If not, rWCVP for Kew's fuzzy matcher | Conditional |
| Occurrence cleaning | R | CoordinateCleaner, as a containerized Dagster step with renv-locked dependencies. Chosen for its curated reference data (institution coordinates, centroids, capitals) and citability | Decided |
| Raster sampling (CHELSA, SoilGrids) | Python | Rasterio for local rasters, httpx + cache for the SoilGrids REST API; GeoPandas/Shapely for geometry | Decided |
| Transforms (silver, gold) | SQL | dbt Core; DuckDB adapter for silver, Postgres adapter for gold | Decided |
| Orchestration | Python | Dagster with the dbt and Great Expectations integrations | Decided |
| Data quality | Python | Great Expectations Core; Pandera for geospatial checks GX cannot express | Decided |
| Serving database | SQL | PostgreSQL 16+ with PostGIS; gold objects owned by dbt | Decided |
| API | C# | ASP.NET Core minimal API on .NET 10, EF Core, Npgsql + NetTopologySuite | Decided |
| Species page | TypeScript | React with Vite, MapLibre GL for the occurrence map; a standalone app consuming the API, so it is the first downstream consumer | Decided |
| DwC-A and EML export | Python | Custom writer over silver Parquet: CSV cores and extensions, meta.xml, EML | Decided |
| Deployment | YAML | Docker Compose on the Hetzner box, Caddy as reverse proxy; Kubernetes (k3s) deferred to Phase 3 | Decided |
| Tests | — | pytest, dbt tests, testthat for the R step, xUnit for the API | Decided |

Data access: EF Core, with keyless entity types over the gold materialized views and NetTopologySuite mapping for geometry. Complex queries stay in dbt views so the API only issues simple selects; write endpoints in Phase 3 get change tracking and transactions for free.

R beyond 1.1: species distribution modelling (ENMeval, biomod2), IUCN range metrics (red, ConR), and reproducibility material for the methodology paper — all Phase 2 or later, each as a containerized step.

**Scaffolding**

One Git repository (monorepo), one folder per component, each using its own language-native tooling. No JavaScript monorepo tool (Turborepo, Nx): there is exactly one JS package, and those tools cannot see Python, R, or .NET.

```
TerraPlantarum/
  pipeline/      Python — Dagster, dbt, GX, ingestion, export (uv)
  clean-r/       R — CoordinateCleaner step, renv.lock, Dockerfile
  api/           C# — solution and projects
  web/           React app (npm)
  infra/         docker-compose.yml, Caddyfile, .env.example
  _docs/         plan, schema, ADRs
  justfile       cross-language task runner: just up, just pipeline, just test
```

*Containers* — one docker-compose.yml with profiles, so infrastructure can run alone during development. The Compose project is named `terraplantarum`, which prefixes every container, volume, and network, so service names carry no prefix of their own:

| Group | Container | Role |
| --- | --- | --- |
| Infrastructure | seaweedfs | The lake; single-node `weed mini` |
| Infrastructure | lakefs | Versioning in front of SeaweedFS; single-node mode with its own local KV store |
| Infrastructure | postgres | One PostGIS image, two databases: terraplantarum (gold) and dagster (run history) |
| Infrastructure | caddy | Reverse proxy and TLS for the API, species page, Dagster UI, lakeFS UI, and SeaweedFS admin UI; operator UIs private-only |
| Pipeline | dagster-webserver | Dagster UI |
| Pipeline | dagster-daemon | Schedules and run queue |
| Pipeline | pipeline | Python code location: ingestion, dbt, GX, export, DuckDB embedded |
| Pipeline | clean-r | R image with CoordinateCleaner; launched per run by Dagster Pipes, reads and writes Parquet, exits |
| Serving | api | .NET API |
| Serving | web | Built React app as static files (Caddy can serve these directly; separate container kept for clarity) |

*Set up at scaffold time, because each is painful to add later:*

- GitHub as the public home of the code (R18), with the Zenodo integration so tagged releases mint DOIs automatically. Gitea can mirror it for a sovereign copy.
- CI from day one via GitHub Actions: pytest, dbt tests, testthat, dotnet test, and a Compose build. Not deployment yet — just keeping four language stacks honest.
- pre-commit with ruff for Python, a SQL formatter, and dotnet format.
- Architecture Decision Records in _docs/adr/, starting with the decisions already made here: WCVP over COL, TCS concept relations, CHELSA-only in 1.1, R for cleaning, EF Core.
- .env.example naming every secret, and Compose secrets so nothing lands in Git.

### Phase 1.1 — Requirements

Phase 1.1 is done when every requirement below is met for Anthurium. Requirements are grouped by what they constrain; "must" is a 1.1 gate, "should" is preferred but can slip to 1.2.

**Pipeline (functional)**

- R1. Must ingest the full Anthurium name list from WCVP (accepted, synonym, and unplaced names with authorship and basionym links) as the taxonomic authority, then load Catalogue of Life XR identifiers as the crosswalk to GBIF, storing any disagreement on accepted names.
- R2. Must attach a growth-habit value per species from EpiList and WCVP, storing both values and their source when they disagree.
- R3. Must pull all GBIF occurrences for those species keyed by COL taxon key, and keep the raw pull unmodified in bronze.
- R4. Must apply a documented, versioned set of cleaning rules and record, per species, how many occurrences entered and how many survived each rule.
- R5. Must sample CHELSA bioclimatic variables and SoilGrids soil variables at every surviving occurrence and cache the results.
- R6. Must produce, per species with at least one surviving occurrence, a profile per variable containing occurrence count, min, max, median, and 5th/25th/75th/95th percentiles, labelled confidence: provisional.
- R7. Must produce no computed profile for a species with zero surviving occurrences, while still exposing its taxon record and raw occurrence count.
- R8. Must write every profile value into the observations table with source\_type = habitat\_calculated and a source\_id pointing to the pipeline run.

**Darwin Core (interoperability)**

- R9. Every occurrence must retain its Darwin Core terms end to end: at minimum occurrenceID, datasetKey, basisOfRecord, decimalLatitude, decimalLongitude, coordinateUncertaintyInMeters, establishmentMeans, eventDate, recordedBy, dateIdentified, and identifiedBy, plus the identification history extension where the publisher provides it (ADR 0011).
- R10. Taxon records must use Darwin Core Taxon terms (taxonID, scientificName, scientificNameAuthorship, taxonRank, taxonomicStatus, acceptedNameUsageID, parentNameUsageID, scientificNameID, nameAccordingTo). taxonID is the permanent PKI taxon ID as a resolvable HTTPS URI; scientificNameID is the IPNI ID; nameAccordingTo is the WCVP release. COL, WCVP, IPNI and POWO IDs are exported as identifiers from taxon\_identifiers.
- R11. Computed profile values must be exportable as MeasurementOrFact rows (measurementType, measurementValue, measurementUnit, measurementMethod) attached to the taxon, so a Darwin Core Archive can be produced.
- R12. Growth habit must be stored as a MeasurementOrFact with a controlled vocabulary, since Darwin Core has no dedicated term; the vocabulary (EpiList's categories as the base) is documented in the archive metadata.
- R13. Internal schema stays PKI's own; Darwin Core is enforced at the export and API layer via a documented 1:1 field mapping, per the architecture spec's aligned-not-native principle.

**FAIR**

- R14. Findable: the Phase 1.1 output is deposited with a DOI (Zenodo) and described with machine-readable metadata (EML for the archive, DataCite for the deposit).
- R15. Accessible: the archive and the API are reachable over plain HTTPS with no authentication for the free tier.
- R16. Interoperable: the output is a Darwin Core Archive (Occurrence core + MeasurementOrFact extension) plus the same data as GeoParquet; variable names for climate and soil use the source datasets' own identifiers (CHELSA bio1–bio19, SoilGrids property codes) rather than invented ones.
- R17. Reusable: every occurrence carries its source dataset's license and citation; every derived value carries the license of the raster it was sampled from; the output as a whole carries a license no more restrictive than the most restrictive input, and the GBIF derived-dataset DOI is registered so upstream publishers get citation credit.
- R18. Reusable: the pipeline code, cleaning rules, and run configuration are public and versioned, and a run is reproducible from the lakeFS commit and the code tag alone.

**Provenance and quality**

- R19. Every pipeline run is a lakeFS commit with the Dagster run ID, code version, source dataset versions (WCVP release, COL release, CHELSA version, SoilGrids version, GBIF download DOI), and cleaning-rule version recorded.
- R20. Great Expectations suites run on bronze and silver; a failing suite blocks promotion to the next tier and the failure is logged, not silently dropped.
- R21. No observation is ever updated or deleted; a re-run produces new observations with a new source\_id.

**Open decisions for these requirements**

- [ ] Output license: CC BY 4.0 is the likely floor given SoilGrids and WCVP are CC BY; confirm each input's license (COL XR, EpiList, individual GBIF datasets) before choosing.
- [ ] Whether to register the derived-dataset DOI with GBIF on every run or only on tagged releases.
- [ ] Resolved: both, by tier. Silver holds one row per occurrence-variable (the sampled values); gold holds one row per species-variable (the profile). The archive can export either.

### Phase 1.1 — Schema

The schema is designed per tier. Bronze has no designed schema: it is the raw pulls, stored as delivered, partitioned by source and pull date. Silver is where the design effort goes; it is Parquet in SeaweedFS, built by dbt models over DuckDB. Gold is the PostGIS serving schema on a separate Postgres instance from the WanderRoot accession database, loaded from silver. Table and column names are PKI's own; the Darwin Core mapping at the end is how they leave the system (R13).

**Conventions**

- Taxa get PKI-minted permanent IDs, because upstream taxon IDs belong to name usages and change when names are recombined or merged; external IDs live in the taxon\_identifiers crosswalk. Occurrence and dataset keys from GBIF are kept as-is and used as primary keys.
- Every silver table carries `run_id`. Nothing in silver is updated in place; a re-run writes the new state to a lakeFS branch and commits, so history lives in lakeFS rather than in the folder layout.
- Variable names are the source's own codes (`chelsa_bio1`, `soilgrids_phh2o_0-5cm`), registered once in `variables` (R16).
- The taxonomy is kingdom-rooted and code-aware from day one, so PKI can expand beyond plants without a schema change: the rank enum runs kingdom → phylum/division → class → order → family → subfamily → tribe → genus → subgenus → section → series → species → subspecies → variety → form, kingdom rows have a null parent, and every name records which nomenclatural code governs it (ICN for plants, algae and fungi; ICZN for animals; ICNP for prokaryotes). The taxonomic authority is per kingdom via taxa.source\_id — WCVP for plants, something else later for anything else.
- Foreign keys are always the target table's primary key column name (source\_id, run\_id, taxon\_id); no column is a bare 'source' or 'rule'.

**Silver — reference**

| Table | Key columns | Notes |
| --- | --- | --- |
| taxa | taxon\_id (PKI-minted, permanent), rank, parent\_taxon\_id, accepted\_name\_id, source\_id, created\_run\_id | The concept, not the name: one row per taxon at any rank from kingdom down to form. Hierarchy via parent\_taxon\_id, rooted at kingdom rows with a null parent; 1.1 populates Plantae → Tracheophyta → Liliopsida → Alismatales → Araceae → Anthurium and below, with subgenus, section, and series reserved for the infrageneric classification in 1.2. Habitat aggregation rolls infraspecific taxa up into their species. The accepted name is a pointer into taxon\_names, so it can change without the taxon ID changing. A taxon ID is a lineage of congruent concepts: renames keep the ID, merges and splits create new taxa linked through taxon\_concept\_relations. source\_id is whose concept this is (the WCVP release) — dwc:nameAccordingTo. WCVP is the authority that mints taxa and sets the accepted name; COL is matched onto existing taxa afterwards |
| taxon\_names | name\_id, taxon\_id (nullable), name\_string, canonical\_name, authorship, nomenclatural\_code, rank, genus\_part, specific\_epithet, infraspecific\_epithet, is\_hybrid, taxonomic\_status, nomenclatural\_status, according\_to, basionym\_name\_id, published\_in, year, valid\_from, valid\_to, source\_id | The nomenclature history: every name ever applied to the taxon. Two statuses, not one: taxonomic\_status ∈ accepted, synonym, misapplied, unplaced (the name's relation to the concept; unplaced names are loaded with a null taxon\_id rather than filtered out) and nomenclatural\_status ∈ legitimate, illegitimate, invalid, conserved, rejected (its standing under the ICN). Which name is current is taxa.accepted\_name\_id, not a flag here. authorship is one formatted string per ICN convention, never split into people; unique key is (name\_string, authorship, nomenclatural\_code) because homonyms exist within a code and the same name can be validly used under different codes (hemihomonyms across kingdoms). nomenclatural\_code is dwc:nomenclaturalCode; ICN for everything in 1.1. basionym\_name\_id links a recombination to the name it came from. canonical\_name (no authorship) backs fuzzy resolution. according\_to holds the 'sensu' for misapplied names |
| taxon\_crosschecks (derived) | taxon\_id, wcvp\_accepted\_name, col\_id, col\_accepted\_name, agrees, run\_id | R1. WCVP wins; COL disagreements are stored, never resolved automatically, and surfaced on the species page as 'COL differs'. A dbt model derived from taxon\_names and taxon\_identifiers, not a base table, so it can never drift from them |
| growth\_habit | taxon\_id, source\_id, value, raw\_value, run\_id | R2, R12. One row per taxon per source; value is the controlled vocabulary, raw\_value is the source's original string |
| variables | variable\_id, label, unit, source\_id, description | Registry of every sampled environmental variable |
| sources | source\_id, source\_type, name, version, license, citation, doi, rights\_holder, reliability\_score, run\_id (nullable) | One row per dataset version: each WCVP and COL release, each CHELSA and SoilGrids version, each GBIF dataset key, and one row per pipeline run (source\_type = pipeline\_run, run\_id set) so computed observations have a source like any other. rights\_holder and citation are what R17 propagates to the export |
| taxon\_identifiers | taxon\_id, name\_id (nullable), system, external\_id, source\_id | Crosswalk to every external ID: COL, IPNI, WCVP, POWO, GBIF. name\_id set when the external ID is for a specific name usage rather than the concept. This is how GBIF occurrences (keyed by COL) find their PKI taxon |
| taxon\_concept\_relations | from\_taxon\_id, to\_taxon\_id, relation, according\_to (source\_id), basis, reference, run\_id | ADR 0007. TDWG Taxon Concept Schema model. relation ∈ congruent, includes, included\_in, overlaps, excludes (RCC-5). Written automatically when a new WCVP release changes a circumscription: rename = congruent, no new taxon; merge = two included\_in rows; split = included\_in rows, with occurrences placed by ADR 0011. Empty on the first release. Gold views follow relations to the current concept |

**Silver — occurrence**

| Table | Key columns | Notes |
| --- | --- | --- |
| occurrences | occurrence\_id (GBIF key), taxon\_id, verbatim\_scientific\_name, gbif\_taxon\_key, dataset\_key, basis\_of\_record, occurrence\_status, decimal\_latitude, decimal\_longitude, coordinate\_uncertainty\_m, elevation\_m, country\_code, establishment\_means, event\_date, recorded\_by, date\_identified, identified\_by, assignment\_basis, gbif\_issues, license, run\_id | R9. GeoParquet with a geometry column. Every occurrence pulled, cleaned or not. verbatim\_scientific\_name and gbif\_taxon\_key keep the name as recorded so the resolution to taxon\_id is auditable; date\_identified, identified\_by and assignment\_basis record how a record was placed after a split (ADR 0011); elevation\_m (dwc:minimumElevationInMeters) is kept because recorded elevation often beats raster-inferred elevation in Andean terrain. occurrence\_status matters: GBIF carries absence records and they must never reach a habitat profile. country\_code enables the standard country/coordinate mismatch check. Coordinates are WGS84 as GBIF delivers them |
| cleaning\_rules | rule\_id, version, description, parameters | R4. The rule set is data, not just code, so a run can cite which version it applied |
| occurrence\_cleaning | occurrence\_id, rule\_id, passed, run\_id | One row per occurrence per rule. Survivors are occurrences with no failed row; per-rule attrition counts come from this table |
| environmental\_samples | occurrence\_id, variable\_id, value, source\_id, run\_id | R5, R11 (occurrence level). One row per surviving occurrence per variable |

**Silver — observations**

| Table | Key columns | Notes |
| --- | --- | --- |
| observations | observation\_id, taxon\_id, parameter\_type, value\_min, value\_max, value\_categorical, unit, context, stats (JSON), source\_id, source\_type, extraction\_method, confidence, review\_status, observed\_at, run\_id | R6–R8, R21. The architecture spec's table, unchanged, plus a stats JSON holding n\_occurrences, median, p05, p25, p75, p95. JSON because other source types (literature, sensor) will not have percentiles. parameter\_type = variable\_id for habitat rows; source\_type = habitat\_calculated; confidence = provisional for 1.1 |
| pipeline\_runs | run\_id, dagster\_run\_id, code\_version, lakefs\_commit, cleaning\_rules\_version, source\_versions (JSON), started\_at, finished\_at, status | R19. One row per Dagster run; source\_versions lists every source\_id consumed |
| quality\_checks | check\_id, run\_id, tier, suite\_name, passed, summary (JSON), results\_uri | R20. One row per Great Expectations suite per run per tier. A failed row is what blocked promotion; results\_uri points at the Data Docs output in SeaweedFS |
| releases | release\_id, version, title, doi, gbif\_derived\_dataset\_doi, license, run\_id, lakefs\_commit, archive\_uri, metadata\_uri, released\_at | R14, R17. One row per published dataset: the Zenodo DOI, the GBIF derived-dataset DOI, the output license, and where the Darwin Core Archive and its EML live. A release is cut from exactly one run |

**Gold — PostGIS serving schema**

Gold is the subset of silver the API needs, loaded into Postgres by dbt, plus computed views:

- `taxa`, `taxon_names`, `growth_habit`, `sources`, `pipeline_runs`, `taxon_identifiers`, `releases` loaded as-is.
- `occurrences` with a PostGIS `geom` column (SRID 4326) and a GiST index; only survivors plus a `cleaned` flag, so the map can show both.
- `observations` append-only, indexed on (taxon\_id, parameter\_type).
- `habitat_profiles` materialized view: latest observation per taxon per variable, with stats unpacked into columns, plus the replacing taxon for any concept with a relation to a newer one (ADR 0007). This is what the species page reads.
- `taxon_summary` materialized view: per taxon, raw occurrence count, cleaned count, whether a profile exists (R7).
- `taxon_classification` materialized view: the parent chain flattened into kingdom, phylum, class, order, family, genus columns per taxon, so Darwin Core's flat higher-taxonomy terms export without a recursive query and the API can filter by any rank.

**Darwin Core export mapping**

| PKI | Darwin Core |
| --- | --- |
| occurrences.occurrence\_id | dwc:occurrenceID |
| occurrences.dataset\_key | dwc:datasetID |
| occurrences.basis\_of\_record | dwc:basisOfRecord |
| occurrences.decimal\_latitude / decimal\_longitude | dwc:decimalLatitude / dwc:decimalLongitude |
| occurrences.coordinate\_uncertainty\_m | dwc:coordinateUncertaintyInMeters |
| occurrences.establishment\_means | dwc:establishmentMeans |
| occurrences.event\_date | dwc:eventDate |
| occurrences.recorded\_by | dwc:recordedBy |
| taxa.taxon\_id | dwc:taxonID (PKI ID); COL ID exported alongside from taxon\_identifiers |
| taxon\_names.name\_string / authorship (via taxa.accepted\_name\_id) | dwc:scientificName / dwc:scientificNameAuthorship |
| taxon\_names.rank / taxonomic\_status / nomenclatural\_status / taxa.accepted\_name\_id | dwc:taxonRank / dwc:taxonomicStatus / dwc:nomenclaturalStatus / dwc:acceptedNameUsageID |
| environmental\_samples (one row) | eMoF row on the occurrence: measurementType = variable\_id, measurementValue, measurementUnit, measurementMethod = source citation |
| observations habitat row | eMoF row on the taxon: measurementType = variable\_id, measurementValue = median, measurementRemarks = min/max/n |
| growth\_habit | eMoF row on the taxon: measurementType = growthHabit, measurementValue from the controlled vocabulary |
| occurrences.verbatim\_scientific\_name / elevation\_m | dwc:verbatimScientificName / dwc:minimumElevationInMeters |
| taxa.source\_id → sources.citation | dwc:nameAccordingTo |
| releases (one row) | The archive's EML metadata: title, DOI, license, citation, version |
| taxon\_names.basionym\_name\_id / published\_in / year / according\_to | dwc:originalNameUsageID / dwc:namePublishedIn / dwc:namePublishedInYear / dwc:nameAccordingTo (for misapplied usages) |
| taxon\_names.genus\_part / specific\_epithet / infraspecific\_epithet | dwc:genericName / dwc:specificEpithet / dwc:infraspecificEpithet |
| taxa.parent\_taxon\_id | dwc:parentNameUsageID |
| taxon\_classification (view) | dwc:kingdom / dwc:phylum / dwc:class / dwc:order / dwc:family / dwc:genus |
| taxon\_names.nomenclatural\_code | dwc:nomenclaturalCode |
| occurrences.occurrence\_status / country\_code / license | dwc:occurrenceStatus / dwc:countryCode / dcterms:license |
| sources.rights\_holder / citation (via occurrences.dataset\_key) | dcterms:rightsHolder / dcterms:bibliographicCitation |
| taxon\_concept\_relations (one row) | TCS TaxonConceptMapping: subject and object concept, RCC-5 relationship, accordingTo |

**Open schema questions**

- [ ] TODO (once in the data): build the mapping table from WCVP's lifeform strings to the growth\_habit controlled vocabulary, using EpiList's categories as the base (holo-epiphyte, hemiepiphyte, terrestrial, etc.).
- [ ] Whether `taxon_names` — resolved: no vernacular (common) names in 1.1. The name\_type value stays in the enum for later; nothing in the Habitat Engine needs them and WCVP does not supply them.
- [ ] Resolved — Parquet partitioning (Hive-style): occurrences, occurrence\_cleaning, and observations by genus; environmental\_samples by genus then source; reference tables (taxa, taxon\_names, taxon\_identifiers, growth\_habit, sources, variables, etc.) not partitioned. Never by run\_id — versions are lakeFS commits, run\_id stays a column.

### Phase 1.1 — Work breakdown

The steps run in dependency order. Steps 1 and 2 are schema work and gate everything after them.

1. Pull the Anthurium name list from WCVP (accepted names, synonyms, unplaced names, infraspecific taxa, authorship, basionyms, lifeform) and mint PKI taxa from it. Then load COL XR, match its name usages onto the existing taxa via the crosswalk, and log any disagreement on accepted names rather than resolving it. On every re-run, check the crosswalk before minting, and diff accepted names against the previous release to write taxon\_concept\_relations.
2. Finalize the observations schema and the reference tables (taxa, taxon\_names, taxon\_identifiers, sources, variables) so step 6 has somewhere to write.
3. Pull GBIF occurrences for every species in the genus, keyed by COL taxon key. Keep the raw pull untouched.
4. Clean and filter occurrences: drop records without coordinates, cultivated and captive records, zero/zero and country-centroid coordinates, records flagged by GBIF quality checks, and duplicates. Record how many occurrences survive per species — that count feeds confidence.
5. Query soil and climate values at every surviving occurrence's coordinates. Cache results so re-runs do not re-query.
6. Aggregate per species, rolling infraspecific taxa up through parent\_taxon\_id: for each variable, a range, a central value, and a confidence characterization driven by occurrence count and the spread of values across those occurrences. Write each as an observation with the habitat-calculated source type.
7. Render a species page for one species that shows the profile, the point count behind it, and a map of the occurrences used.
8. Version and archive the run: the genus list, the raw occurrence pull, the cleaning rules applied, and the outputs, so the demo is reproducible and citable.

### Phase 1.1 — GitHub issues

One milestone (`phase-1.1`). Issues are listed in execution order: each depends only on issues above it, so working top to bottom never blocks. Stages are labels (`stage:0-scaffold` … `stage:7-release`); language labels `python`, `r`, `sql`, `dotnet`, `web`, `infra`, `docs`. Each issue names the requirement it satisfies. Sized so that most are a day or two; none should exceed a week.

**Stage 0 — Scaffold**

1. **Monorepo skeleton** — folder layout, justfile stubs (`up`, `down`, `test`), README, code LICENSE, per-language .gitignore. *Done:* fresh clone, `just --list` works.
2. **Compose: infrastructure profile** — seaweedfs, lakefs (single-node, local KV), postgres (PostGIS image; `terraplantarum` and `dagster` databases created by init script), caddy; `.env.example`. *Done:* lakeFS and the SeaweedFS admin UI reachable through Caddy; Postgres reachable on localhost only.
3. **Compose: pipeline profile** — dagster-webserver, dagster-daemon, pipeline with `uv` and one hello-world asset. *Done:* asset materializes from the UI.
4. **CI** — GitHub Actions: pytest, dbt parse, dotnet build, Compose build. R added at 27. *Done:* green on main.
5. **pre-commit** — ruff, sqlfluff, dotnet format.
6. **First five ADRs** — WCVP over COL; TCS concept relations; CHELSA only; R for cleaning; EF Core. (`docs`)

**Stage 1 — Schema**

7. **dbt project for silver** — dbt-duckdb configured against SeaweedFS via lakeFS, `sources.yml` for bronze, empty models directory, `dbt parse` in CI. (R13)
8. **Silver reference tables** — models and schema tests for `taxa`, `taxon_names`, `taxon_identifiers`, `taxon_concept_relations`, `growth_habit`, `variables`, `sources`; unique key on (name\_string, authorship, nomenclatural\_code); nullable `taxon_id`. (R10, R21)
9. **Silver occurrence tables** — `occurrences` (GeoParquet, geometry column), `cleaning_rules`, `occurrence_cleaning`, `environmental_samples`; partition by genus, and by source for samples. (R9)
10. **Silver run and observation tables** — `observations` (with `stats` JSON), `pipeline_runs`, `quality_checks`, `releases`. (R6, R19, R20, R14)
11. **Pipeline write helpers** — Python module that writes Parquet to the right partition, opens a lakeFS branch per run, commits with `run_id` and code version, and stamps `run_id` on every frame. Every later ingestion issue uses this. (R19, R21)
12. **Gold schema in Postgres** — dbt Postgres target; tables loaded from silver; `occurrences.geom` with GiST; materialized views `habitat_profiles`, `taxon_summary`, `taxon_classification` defined (empty for now). (R13)
13. **Seed `variables` and `sources`** — CHELSA bio1–bio19, SoilGrids properties, WCVP and COL release rows, with units, licenses, citations, DOIs, rights holders. (R16, R17)
14. **Seed the kingdom-to-genus backbone** — Plantae → Tracheophyta → Liliopsida → Alismatales → Araceae → Anthurium as `taxa` and `taxon_names` rows, ICN code. (R10)

**Stage 2 — Taxonomy**

15. **WCVP to bronze** — download the release, filter to Anthurium (all statuses, infraspecific, lifeform), land untouched, `sources` row with version. (R1)
16. **Mint taxa from WCVP accepted names** — one `taxa` row per accepted name at species and infraspecific rank, parent links, `source_id` = the WCVP release; re-run checks `taxon_identifiers` first and never re-mints. (R1, R10)
17. **Load taxon\_names from WCVP** — every name: authorship string, name parts, statuses, basionym link, `published_in`, year; synonyms attached to their taxon, unplaced with null `taxon_id`; `taxa.accepted_name_id` set. (R1, R10)
18. **COL XR to bronze and the WCVP-ID check** — pull Anthurium usages; determine whether COL carries WCVP IDs. *Done:* a written finding in the issue, and either a join (19) or a follow-up issue for rWCVP.
19. **Populate taxon\_identifiers** — COL, WCVP, IPNI, POWO IDs per taxon and per name usage. *Done:* every COL usage for Anthurium resolves to a PKI taxon or is listed as unresolved. (R1)
20. **taxon\_crosschecks model** — dbt model of WCVP/COL accepted-name disagreements. (R1)
21. **EpiList to bronze** — the Anthurium subset of the Zotz et al. checklist with its categories and citation. (R2)
22. **Growth habit load and lifeform mapping** — the WCVP-lifeform → vocabulary mapping table (the TODO), then one `growth_habit` row per taxon per source. (R2, R12)
23. **Release diff and taxon\_concept\_relations** — diff accepted names between two WCVP releases (test with two historical ones), write congruent/included\_in rows, place split occurrences by ADR 0011. May slip to 1.2 without blocking anything below. (R19)

**Stage 3 — Occurrences**

24. **GBIF download for Anthurium** — async download request by COL taxon keys, DwC-A landed in bronze untouched, download DOI in `sources`. (R3)
25. **Load occurrences to silver** — DwC term mapping to columns (incl. `occurrence_status`, `country_code`, `verbatim_scientific_name`, `gbif_taxon_key`, `license`), `taxon_id` via crosswalk, GeoParquet. (R9)
26. **Cleaning rules as data** — `cleaning_rules` rows: each CoordinateCleaner test to be used, plus PKI rules (absence records, cultivated/captive, missing coordinates, GBIF issue flags), versioned `v1`. (R4)
27. **R cleaning image** — `clean-r/` Dockerfile, renv.lock with CoordinateCleaner, testthat smoke test, added to CI. *Done:* container reads a Parquet fixture and writes one. (R4)
28. **Dagster Pipes wrapper for the R step** — launches the container per run, passes the run's branch and partition, collects exit status. *Done:* invoked from the Dagster UI end to end.
29. **Run cleaning and write occurrence\_cleaning** — one row per occurrence per rule; PKI rules in Python, CoordinateCleaner rules in R. (R4)
30. **Attrition model** — dbt model: per species, occurrences in, out per rule, surviving; feeds `taxon_summary`. (R4, R7)

**Stage 4 — Environment**

31. **CHELSA bio1–bio19 to bronze** — versioned download, checksums, `sources` row. (R5)
32. **Sample CHELSA at survivors** — Rasterio extraction, `environmental_samples` rows, idempotent on re-run. (R5, R11)
33. **SoilGrids cache and sampling** — REST client with a persistent cache keyed by rounded coordinate; `environmental_samples` rows for the chosen properties and depths. (R5, R11)

**Stage 5 — Aggregation**

34. **Habitat aggregation model** — per taxon per variable with infraspecific roll-up: count, min, max, median, percentiles → `observations` rows, `habitat_calculated`, `confidence = provisional`, pipeline-run `sources` row; zero survivors → no row. (R6, R7, R8)
35. **Great Expectations suites** — bronze and silver suites (row counts, not-null, key uniqueness, coordinate ranges, occurrence\_status values); results to `quality_checks`; failure blocks the next tier. (R20)
36. **End-to-end Dagster job** — every asset wired with dependencies, `pipeline_runs` written, one job materializes 1.1 from bronze to observations. (R19)
37. **Gold load** — dbt run against Postgres; views populated; `taxon_classification` verified against the seeded backbone. *Done:* `SELECT * FROM habitat_profiles WHERE …` returns Anthurium warocqueanum.

**Stage 6 — Serving**

38. **API skeleton and `/v1/taxa/{id}`** — minimal API, EF Core keyless entities over gold, provenance envelope (source count, run, last calculated). A replaced taxon ID returns its record, the current concept and the relation, never not-found (ADR 0007). (R15)
39. **`/v1/taxa/{id}/habitat` and `/v1/taxa/{id}/occurrences`** — profile with stats and provenance; occurrences as GeoJSON. (R15)
40. **`/v1/resolve?name=`** — pg\_trgm over `canonical_name`, returns candidates with scores and the resolution path.
41. **Species page: taxon and habitat** — React + Vite: accepted name, synonyms, growth habit, 'COL differs', profile table with counts and spread.
42. **Species page: occurrence map** — MapLibre layer from the occurrences endpoint, cleaned vs. dropped styled differently.
43. **Caddy routing and TLS** — API, web, Dagster, lakeFS behind hostnames. API and web are public; operator UIs (lakeFS, Dagster, SeaweedFS admin) answer only private addresses, with the same Caddyfile locally and in production. *Done:* species page loads over HTTPS from the Hetzner box, and operator UIs refuse public requests.

**Stage 7 — Release**

44. **Input licenses and output license ADR** — confirm WCVP, COL XR, EpiList, CHELSA, SoilGrids, each GBIF dataset; choose the output license. (R17)
45. **DwC-A writer: occurrence core** — CSV plus `meta.xml`, per-record license and citation columns. (R11, R16, R17)
46. **DwC-A writer: Taxon and MeasurementOrFact extensions** — taxon rows with statuses and higher classification; eMoF at occurrence and taxon level. (R11, R12)
47. **EML generator** — from the `releases` row. (R14)
48. **GBIF derived-dataset registration** — script registering dataset keys and counts, DOI stored in `releases`. (R17)
49. **GitHub release → Zenodo DOI** — tag, archive attached, DOI stored in `releases`. (R14, R18)
50. **Methods write-up** — sources and versions, cleaning rules with the CoordinateCleaner citation, aggregation definition, known gaps. (`docs`)
51. **README and contributor guide** — how to run, the tiers, where decisions live. (`docs`)

### Phase 1.1 — Known gaps and open questions

**Accepted gaps**

- Soil profiles for epiphytes describe the ground beneath the plant, not the plant's substrate. They are stored but flagged low-confidence by growth habit.
- No light or canopy environment yet.
- Occurrence points for rare species may be too few to aggregate meaningfully; those species get a profile with a wide confidence band, which is the honest answer.

**Open questions**

- [ ] Resolved: Anthurium.
- [ ] Resolved: EpiList + WCVP for growth habit. Still to check: that WCVP's lifeform column is present in the download, and EpiList coverage for Anthurium.
- [ ] Resolved: CHELSA only in 1.1; WorldClim comparison deferred to 1.2.
- [ ] Resolved: no minimum. Any surviving occurrence produces a profile; zero occurrences produces none. Confidence scale deferred to 1.2, once the actual data volume for Anthurium is known. 1.1 stores the inputs it will need — occurrence count and value spread (min, max, percentiles per variable) — and labels every profile "confidence: provisional".

## Phase 2 — Literature and the observation commons

**Goal:** extract values from journal articles into the observations table through a human review step, and combine them with computed habitat values by weighted aggregation that flags conflicts between sources.

**What it has to accomplish**

- Journal archive extraction with a human review loop, so literature-derived values enter the observations table with a recorded confidence.
- Weighted aggregation and conflict detection: calibrated weights, a conflict threshold, and a review queue.
- Conservation status attached to every taxon.
- An API v1 surface stable enough for downstream consumers to build on.

**Success looks like:** a species page shows computed habitat values, literature-derived values and conservation status together, each with its confidence and source.

## Phase 3 — Contribution and feeder systems

**Goal:** add write endpoints so verified contributors outside WanderRoot can submit observations, each weighted by the contributor's trust level.

**What it has to accomplish**

- A verified contributor system whose trust levels directly set observation weight.
- Structured submission of cultivation observations and TC protocol outcomes, including negative results.
- WanderRoot sensor and TC logs pushing in as the highest-weight source, tied to documented provenance.
- The first TC protocol inference: direct lookup, taxonomic transfer, and habitat-similarity transfer, synthesized into a starting point with explicit reasoning. This becomes buildable only once Phase 1 profiles and Phase 2 protocol extractions both exist.
- Governance formalized, with a second society onboarded as the trigger.

**Success looks like:** observations submitted by contributors outside WanderRoot are stored with their provenance, and the aggregated values that include them are recalculated.

## Phase 4 — Intelligence and scale

**Goal:** add a natural-language query interface, related-species and gap-analysis endpoints, and conservation tooling, and run the pipeline on taxa outside Araceae.

**What it has to accomplish**

- A natural-language query interface grounded only in what the database contains, with "I don't know" as the failure mode.
- Related-species and gap-analysis endpoints — high conservation concern plus low data confidence as a research-agenda generator.
- Conservation tooling: collection-pressure assessment, founder-line diversity tracking, and metacollection coordination on verified provenance.
- Expansion beyond Araceae.
- Transition to independent multi-society governance once three or more societies contribute.

**Success looks like:** the query interface answers only from database contents and returns "I don't know" otherwise, and the pipeline produces habitat profiles for at least one genus outside Araceae.

## Open questions before drilling into Phase 1

- [ ] Phase 1 scope: one species done properly, or one genus done adequately? They need different amounts of taxonomy and occurrence-cleaning work.
- [ ] Is the epiphyte/hemiepiphyte habitat definition already settled, or is deciding it a Phase 1 deliverable?
- [ ] Do the terrestrial and epiphyte pipelines get built together or sequentially?
