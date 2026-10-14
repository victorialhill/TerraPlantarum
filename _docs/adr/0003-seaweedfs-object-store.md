# 3. SeaweedFS is the object store, hardened and on a private network

Date: 2026-09-27

## Status

Accepted. Replaces MinIO in the build plan.

## Context

The build plan named MinIO as the S3-compatible store under lakeFS. By September 2026:

- The MinIO repository was archived read-only on 2026-04-25. The community edition is source-only, with no maintained images.
- CVE-2026-40344 (CVSS 8.2), which lets anyone with a valid access key write objects without a valid signature, is fixed only in the proprietary AIStor edition.
- AIStor Free is closed-source, single-node only, and needs a license file.

lakeFS is the only client of the store. DuckDB, boto3 and dbt reach the lake through lakeFS's S3 gateway, so the store needs only basic S3: multipart upload, path-style access and ListObjectsV2. The lakeFS `local` blockstore was ruled out because its documentation calls it non-production and it does not support garbage collection.

The candidates were SeaweedFS (Apache-2.0, long maintenance history, active releases), Garage (AGPL-3.0, no official console) and Silo (an AGPL-3.0 fork of MinIO, recently renamed, run by one organisation). None is officially tested by lakeFS.

With no configuration, `weed mini` also runs an unauthenticated WebDAV server, filer HTTP API, filer IAM gRPC service and admin UI, plus Iceberg and Lance servers, and it sends usage telemetry.

## Decision

Use SeaweedFS (`chrislusf/seaweedfs`) in single-process `weed mini` mode, and harden it:

- S3 credentials are required. The wrapper refuses to start without them.
- The JWT signing keys for volume writes, filer writes and filer reads are set through `WEED_JWT_*` variables, so the filer serves data only to signed requests. `jwt.signing.read` is not set, because SeaweedFS does not support it with a filer.
- The admin UI requires a login.
- WebDAV, Iceberg, Lance and telemetry are turned off.
- The service is only on the `storage` network, which is `internal` (no internet access). Only lakeFS and Caddy join it.

## Consequences

- Every write reaches the lake through lakeFS, so every change can be committed and versioned. The `storage` network enforces this: no other service can reach SeaweedFS.
- The smoke tests (`just test-infra`) check each protection: anonymous S3 refused, unsigned filer reads and writes refused, admin login required, WebDAV closed, no internet route, and a lakeFS round trip.
- lakeFS runs with `blockstore.s3.discover_bucket_region=false`, because SeaweedFS does not support GetBucketRegion.
- gRPC between SeaweedFS components is not mutually authenticated. On one host with an internal network this adds little. If SeaweedFS ever spans more than one host, add gRPC mTLS as described in its `security.toml` template.
