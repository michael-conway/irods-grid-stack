#!/usr/bin/env sh
set -eu

S3_UPSTREAM_IRODS_HOST="${S3_UPSTREAM_IRODS_HOST:-}"
S3_UPSTREAM_IRODS_PORT="${S3_UPSTREAM_IRODS_PORT:-1247}"
S3_UPSTREAM_READY_RETRIES="${S3_UPSTREAM_READY_RETRIES:-180}"
S3_UPSTREAM_READY_DELAY_SECONDS="${S3_UPSTREAM_READY_DELAY_SECONDS:-2}"
S3_API_START_RETRIES="${S3_API_START_RETRIES:-120}"
S3_API_START_RETRY_DELAY_SECONDS="${S3_API_START_RETRY_DELAY_SECONDS:-3}"

wait_for_upstream_irods() {
  if [ -z "$S3_UPSTREAM_IRODS_HOST" ]; then
    return 0
  fi

  if ! command -v nc >/dev/null 2>&1; then
    echo "nc not available in container; skipping TCP preflight wait and using startup retries" >&2
    return 0
  fi

  echo "Waiting for upstream iRODS at ${S3_UPSTREAM_IRODS_HOST}:${S3_UPSTREAM_IRODS_PORT}" >&2
  i=1
  while [ "$i" -le "$S3_UPSTREAM_READY_RETRIES" ]; do
    if nc -z "$S3_UPSTREAM_IRODS_HOST" "$S3_UPSTREAM_IRODS_PORT" >/dev/null 2>&1; then
      echo "Upstream iRODS is reachable" >&2
      return 0
    fi

    echo "Upstream iRODS not ready yet (${i}/${S3_UPSTREAM_READY_RETRIES})" >&2
    sleep "$S3_UPSTREAM_READY_DELAY_SECONDS"
    i=$((i + 1))
  done

  echo "Upstream iRODS did not become reachable in time" >&2
  return 1
}

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

wait_for_upstream_irods

attempt=1
while [ "$attempt" -le "$S3_API_START_RETRIES" ]; do
  echo "Starting irods_s3_api (attempt ${attempt}/${S3_API_START_RETRIES})" >&2
  if [ "$attempt" -eq "$S3_API_START_RETRIES" ]; then
    exec irods_s3_api /tmp/irods-s3-api-config.json
  fi

  if irods_s3_api /tmp/irods-s3-api-config.json; then
    exit 0
  fi

  echo "irods_s3_api exited early; retrying in ${S3_API_START_RETRY_DELAY_SECONDS}s" >&2
  sleep "$S3_API_START_RETRY_DELAY_SECONDS"
  attempt=$((attempt + 1))
done
