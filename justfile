set windows-shell := ["pwsh", "-NoLogo", "-NoProfile", "-Command"]

compose := "docker compose -f infra/docker-compose.yml --env-file infra/.env"

# List recipes
default:
    @just --List

# Start the stack
up:
    {{compose}} up -d

# Stop the stack
down:
    {{compose}} down

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