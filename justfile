set windows-shell := ["pwsh", "-NoLogo", "-NoProfile", "-Command"]

compose := "docker compose -f infra/docker-compose.yml --env-file infra/.env"

# List recipes
default:
    @just --list

# Start the whole stack (every profile)
up:
    {{compose}} --profile "*" up -d

# Start infrastructure only: Postgres, SeaweedFS, lakeFS, Caddy
up-infra:
    {{compose}} --profile infra up -d

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
    @echo "pipeline: no tests yet"

test-r:
    @echo "clean-r: no tests yet"

test-web:
    @echo "web: no tests yet"

# Smoke-test the running infra profile (start it first with 'just up-infra')
test-infra:
    pwsh -NoProfile -Command 'Invoke-Pester -Configuration @{ Run = @{ Path = "infra/tests"; Exit = $true }; Output = @{ Verbosity = "Detailed" }}'
