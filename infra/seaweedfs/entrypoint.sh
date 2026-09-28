#!/bin/sh
# Loads credentials and signing keys from Compose secrets, then hands off to the image's entrypoint.
# weed mini reads S3 credentials only from AWS_* variables and allows anonymous access without them.
set -e
. /terraplantarum/read-secret.sh

AWS_ACCESS_KEY_ID="$(read_secret seaweedfs_s3_access_key)"
AWS_SECRET_ACCESS_KEY="$(read_secret seaweedfs_s3_secret_key)"
WEED_JWT_SIGNING_KEY="$(read_secret seaweedfs_jwt_filer_signing_key)"
WEED_JWT_FILER_SIGNING_KEY="$(read_secret seaweedfs_jwt_filer_signing_key)"
WEED_JWT_FILER_SIGNING_READ_KEY="$(read_secret seaweedfs_jwt_filer_signing_read_key)"
admin_password="$(read_secret seaweedfs_admin_password)"

export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY \
    WEED_JWT_SIGNING_KEY WEED_JWT_FILER_SIGNING_KEY WEED_JWT_FILER_SIGNING_READ_KEY
exec /entrypoint.sh "$@" -admin.password="$admin_password"
