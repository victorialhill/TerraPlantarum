#!/bin/sh
# Loads lakeFS credentials from Compose secrets, then starts lakeFS.
# lakeFS reads configuration only from LAKEFS_* variables or a config file, not from the secret files
set -e
. /terraplantarum/read-secret.sh

LAKEFS_AUTH_ENCRYPT_SECRET_KEY="$(read_secret lakefs_auth_encrypt_secret_key)"
LAKEFS_INSTALLATION_ACCESS_KEY_ID="$(read_secret lakefs_admin_access_key)"
LAKEFS_INSTALLATION_SECRET_ACCESS_KEY="$(read_secret lakefs_admin_secret_key)"
LAKEFS_BLOCKSTORE_S3_CREDENTIALS_ACCESS_KEY_ID="$(read_secret seaweedfs_s3_access_key)"
LAKEFS_BLOCKSTORE_S3_CREDENTIALS_SECRET_ACCESS_KEY="$(read_secret seaweedfs_s3_secret_key)"

export LAKEFS_AUTH_ENCRYPT_SECRET_KEY \
    LAKEFS_INSTALLATION_ACCESS_KEY_ID LAKEFS_INSTALLATION_SECRET_ACCESS_KEY \
    LAKEFS_BLOCKSTORE_S3_CREDENTIALS_ACCESS_KEY_ID LAKEFS_BLOCKSTORE_S3_CREDENTIALS_SECRET_ACCESS_KEY
exec /app/lakefs "$@"
