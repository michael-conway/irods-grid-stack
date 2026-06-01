#!/usr/bin/env sh
set -eu

bucket_plugin="$(find /usr -name 'libirods_s3_api_plugin-bucket_mapping-local_file.so' | head -n 1)"
user_plugin="$(find /usr -name 'libirods_s3_api_plugin-user_mapping-local_file.so' | head -n 1)"

if [ -z "$bucket_plugin" ] || [ -z "$user_plugin" ]; then
  echo "Could not locate iRODS S3 API mapping plugins" >&2
  exit 1
fi

for mapping_file in \
  /shared-s3-config/irods-s3-bucket-mapping.json \
  /shared-s3-config/irods-s3-user-mapping.json
do
  if [ ! -f "$mapping_file" ]; then
    echo "Missing iRODS S3 API mapping file: $mapping_file" >&2
    exit 1
  fi
done

sed \
  -e "s#__BUCKET_MAPPING_PLUGIN__#$bucket_plugin#g" \
  -e "s#__USER_MAPPING_PLUGIN__#$user_plugin#g" \
  /config-template.json > /tmp/irods-s3-api-config.json

: "${IRODS_S3_API_STARTUP_RETRIES:=30}"
: "${IRODS_S3_API_STARTUP_RETRY_DELAY_SECONDS:=2}"

attempt=1
while [ "$attempt" -le "$IRODS_S3_API_STARTUP_RETRIES" ]; do
  echo "Starting iRODS S3 API (attempt $attempt/$IRODS_S3_API_STARTUP_RETRIES)..."

  if irods_s3_api /tmp/irods-s3-api-config.json; then
    exit 0
  else
    status=$?
  fi

  if [ "$attempt" -eq "$IRODS_S3_API_STARTUP_RETRIES" ]; then
    echo "iRODS S3 API failed after $IRODS_S3_API_STARTUP_RETRIES attempts." >&2
    exit "$status"
  fi

  echo "iRODS S3 API exited with status $status; retrying in ${IRODS_S3_API_STARTUP_RETRY_DELAY_SECONDS}s..." >&2
  sleep "$IRODS_S3_API_STARTUP_RETRY_DELAY_SECONDS"
  attempt=$((attempt + 1))
done
