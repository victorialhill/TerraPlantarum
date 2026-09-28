set windows-shell := ["pwsh", "-NoLogo", "-NoProfile", "-Command"]

compose := "docker compose -f infra/docker-compose.yml --env-file infra/.env"

# List recipes
default:
    @just --list

# Start the whole stack (every profile)
up: && reload-caddy
    {{compose}} --profile "*" up -d --build --wait

# Start infrastructure only: Postgres, SeaweedFS, lakeFS, Caddy
up-infra: && reload-caddy
    {{compose}} --profile infra up -d --wait

# Start infrastructure and the pipeline: Dagster webserver, daemon and code location
up-pipeline: && reload-caddy
    {{compose}} --profile infra --profile pipeline up -d --build --wait

# Apply Caddyfile changes to the running Caddy without dropping connections; every up recipe runs it
reload-caddy:
    {{compose}} exec caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile

# Stop the stack; data volumes are kept
down:
    {{compose}} --profile "*" down

# Delete every data volume (including Caddy's CA) and stop; the next `up` re-runs first-start setup
reset:
    {{compose}} --profile "*" down -v

# Run any compose command against the stack, e.g. `just dc logs lakefs`
dc *args:
    {{compose}} --profile "*" {{args}}

# Run every component's tests
test: test-api test-pipeline test-r test-web

test-api:
    dotnet test api/TerraPlantarum.slnx

test-pipeline:
    uv run --project pipeline pytest pipeline/tests

test-r:
    @echo "clean-r: no tests yet"

test-web:
    @echo "web: no tests yet"

# Smoke-test the running stack (start it first with 'just up')
test-infra:
    pwsh -NoProfile -Command 'Invoke-Pester -Configuration @{ Run = @{ Path = "infra/tests"; Exit = $true }; Output = @{ Verbosity = "Detailed" }}'
