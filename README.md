# Terra Plantarum

Turns verified plant occurrence records into confidence-scored native habitat profiles, keyed to an accepted taxonomy and published as a citable, reproducible dataset.

Phase 1 is the Habitat Engine. The plan lives in [`_docs/`](_docs/).

## Layout

| Folder | What | Tooling |
|---|---|---|
| `_docs/` | Build plan, schema, ADRs | Markdown |
| `api/` | Public API | C# / .NET 10, EF Core, Npgsql |
| `pipeline/` | Ingestion, dbt, data quality, export | Python 3.13, uv, Dagster |
| `clean-r/` | Occurrence cleaning (CoordinateCleaner) | R 4.6, renv |
| `web/` | Species pages | React Router 8 on Vite, pnpm |
| `infra/` | Docker Compose, Caddy | Docker |

## Prerequisites

[just](https://github.com/casey/just), Docker, .NET 10 SDK, [uv](https://docs.astral.sh/uv/), R 4.6, Node 24 with pnpm.

## Common tasks

```sh
just          # list recipes
just up       # start the stack
just down     # stop it
just test     # run all tests
```

## License

Code is licensed under [Apache-2.0](LICENSE). Data releases carry their own license.
