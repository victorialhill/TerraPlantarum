# Smoke tests for the infra pipeline: every service is up and every access rule holds.
# Needs the stack runing ('just up-infra'); run with 'just test-infra'. Requires Pester 5+
# Secrets never leave the containers: each check reads what it needs from /run/secrets inside them

BeforeAll {
    $repoRoot = (Resolve-Path "$PSScriptRoot/../..").Path
    $compose = @('compose', '-f', "$repoRoot/infra/docker-compose.yml", '--env-file', "$repoRoot/infra/.env", '--profile', 'infra')

    # Non-secret settings only.
    $settings = @{}
    Get-Content "$repoRoot/infra/.env" |
        Where-Object { $_ -match '^(TERRAPLANTARUM_DOMAIN|SEAWEEDFS_LAKE_BUCKET)=' } |
        ForEach-Object { $name, $value = $_ -split '=', 2; $settings[$name] = $value }
    $domain = $settings.TERRAPLANTARUM_DOMAIN
    $curl = if ($IsWindows) { 'curl.exe' } else {'curl' }
    $nullDevice = if ($IsWindows) { 'NUL' } else { '/dev/null' }

    # Runs a POSIX sh script inside a running service; returns its exit code and combined output.
    function Invoke-InService([string] $Service, [string] $Script) {
        $output = docker @compose exec -T $Service sh -c $Script 2>&1
        [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($output -join "`n").Trim() }
    }
}

Describe 'Services' {
    It '<_> is healthy' -ForEach @('postgres', 'seaweedfs', 'lakefs', 'caddy') {
        docker @compose ps $_ --format '{{.Health}}' | Should -Be 'healthy'
    }
}

#psql connects over TCP (-h 127.0.0.1) so password authentication is exercised,
# not the image's trust rule for local socket connections.
Describe 'Postgres' {
    AfterAll {
        Invoke-InService postgres 'PGPASSWORD="$(cat /run/secrets/terraplantarum_db_password)" psql -h 127.0.0.1 -U "$TERRAPLANTARUM_DB_ROLE" -d "$TERRAPLANTARUM_DB_NAME" -c "drop table if exists smoke_probe"' | Out-Null
    }

    It 'lets the owner role create tables' {
        $result = Invoke-InService postgres 'PGPASSWORD="$(cat /run/secrets/terraplantarum_db_password)" psql -h 127.0.0.1 -U "$TERRAPLANTARUM_DB_ROLE" -d "$TERRAPLANTARUM_DB_NAME" -c "create table smoke_probe (id int); insert into smoke_probe values (1)"'
        $result.ExitCode | Should -Be 0 -Because $result.Output
    }

    It 'lets the API role read what the owner creates' {
        $result = Invoke-InService postgres 'PGPASSWORD="$(cat /run/secrets/terraplantarum_api_db_password)" psql -h 127.0.0.1 -U "$TERRAPLANTARUM_API_DB_ROLE" -d "$TERRAPLANTARUM_DB_NAME" -tAc "select id from smoke_probe"'
        $result.Output | Should -Be '1'
    }

    It 'stops the API role creating tables' {
        $result = Invoke-InService postgres 'PGPASSWORD="$(cat /run/secrets/terraplantarum_api_db_password)" psql -h 127.0.0.1 -U "$TERRAPLANTARUM_API_DB_ROLE" -d "$TERRAPLANTARUM_DB_NAME" -c "create table smoke_denied (id int)"'
        $result.Output | Should -Match 'permission denied'
    }

    It 'keeps the Dagster role out of the gold database' {
        $result = Invoke-InService postgres 'PGPASSWORD="$(cat /run/secrets/dagster_db_password)" psql -h 127.0.0.1 -U "$DAGSTER_DB_ROLE" -d "$TERRAPLANTARUM_DB_NAME" -tAc "select 1"'
        $result.Output | Should -Match 'permission denied for database'
    }

    It 'lets the Dagster role use its own database' {
        $result = Invoke-InService postgres 'PGPASSWORD="$(cat /run/secrets/dagster_db_password)" psql -h 127.0.0.1 -U "$DAGSTER_DB_ROLE" -d "$DAGSTER_DB_NAME" -tAc "select 1"'
        $result.Output | Should -Be '1'
    }
}
Describe 'SeaweedFS' {
    It 'refuses anonymous S3 requests' {
        (Invoke-InService seaweedfs 'curl -s -o /dev/null -w "%{http_code}" http://localhost:8333/').Output | Should -Be '403'
    }

    It 'refuses unsigned filer reads' {
        (Invoke-InService seaweedfs 'curl -s -o /dev/null -w "%{http_code}" http://localhost:8888/buckets/').Output | Should -Be '401'
    }

    It 'refuses unsigned filer writes' {
        (Invoke-InService seaweedfs 'curl -s -o /dev/null -w "%{http_code}" -F "file=@/etc/hostname" http://localhost:8888/buckets/smoke-unsigned').Output | Should -Be '401'
    }

    It 'sends the admin UI to its login page' {
        (Invoke-InService seaweedfs 'curl -s -o /dev/null -w "%{http_code} %{redirect_url}" http://localhost:23646/').Output | Should -Match '^30[27] .*/login$'
    }

    It 'does not run WebDAV' {
        # curl exit code 7: connection refused
        (Invoke-InService seaweedfs 'curl -s -o /dev/null http://localhost:7333/; echo $?').Output | Should -Be '7'
    }

    It 'has no route to the internet' {
        (Invoke-InService seaweedfs 'curl -s -o /dev/null --max-time 5 https://example.com/; echo $?').Output | Should -Not -Be '0'
    }
}

Describe 'lakeFS' {
    BeforeAll {
        $repo = "smoke-$(Get-Date -Format 'yyyyMMddHHmmss')"
        $bucket = $settings.SEAWEEDFS_LAKE_BUCKET
        # lakectl authenticated as the admin, from the secrets inside the container.
        $lakectl = 'LAKECTL_SERVER_ENDPOINT_URL=http://localhost:8000' +
            ' LAKECTL_CREDENTIALS_ACCESS_KEY_ID="$(cat /run/secrets/lakefs_admin_access_key)"' +
            ' LAKECTL_CREDENTIALS_SECRET_ACCESS_KEY="$(cat /run/secrets/lakefs_admin_secret_key)" lakectl'
    }

    AfterAll {
        Invoke-InService lakefs "$lakectl repo delete lakefs://$repo --yes" | Out-Null
    }

    It 'creates a repository in the lake bucket' {
        $result = Invoke-InService lakefs "$lakectl repo create lakefs://$repo s3://$bucket/$repo"
        $result.ExitCode | Should -Be 0 -Because $result.Output
    }

    It 'uploads and commits an object' {
        $result = Invoke-InService lakefs "echo smoke > /tmp/smoke.txt && $lakectl fs upload lakefs://$repo/main/smoke.txt --source /tmp/smoke.txt && $lakectl commit lakefs://$repo/main -m smoke"
        $result.ExitCode | Should -Be 0 -Because $result.Output
    }

    It 'reads the committed object back' {
        (Invoke-InService lakefs "$lakectl fs cat lakefs://$repo/main/smoke.txt").Output | Should -Match '(?m)^smoke$'
    }
}

# --resolve pins each site name to this machine, so no DNS entry is needed;
# -k skips certificate trust because this checks routing not the local CA.
Describe 'Caddy' {
    BeforeAll {
        function Get-Response([string] $Url) {
            $site = ([uri] $Url).Host
            & $curl -sk --resolve "${site}:443:127.0.0.1" --resolve "${site}:80:127.0.0.1" -o $nullDevice -w '%{http_code} %{redirect_url}' $Url
        }
    }

    It 'serves lakeFS over HTTPS' {
        Get-Response "https://lakefs.$domain/" | Should -Match '^200'
    }

    It 'serves the SeaweedFS admin login over HTTPS' {
        Get-Response "https://seaweedfs.$domain/" | Should -Match '^30[27] .*/login$'
    }

    It 'redirects plain HTTP to HTTPS' {
        Get-Response "http://lakefs.$domain/" | Should -Match '^308 https://'
    }
}
