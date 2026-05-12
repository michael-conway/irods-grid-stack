#!/usr/bin/env bash
set -euo pipefail

# Idempotent provider-side setup to run after irods-provider is healthy.
# This is separate from the inherited DRS test setup so that this project can
# grow its own grid-specific fixtures without changing irods-go-drs.

: "${IRODS_ZONE:=tempZone}"
: "${IRODS_ADMIN_USER:=rods}"
: "${IRODS_PRIMARY_TEST_USER:=test1}"
: "${IRODS_PRIMARY_TEST_PASSWORD:=test}"
: "${IRODS_SECONDARY_TEST_USER:=test2}"
: "${IRODS_SECONDARY_TEST_PASSWORD:=test}"

create_user() {
  local user_name="$1"
  local user_type="$2"
  local password="$3"

  if ! iadmin lu "$user_name" >/dev/null 2>&1; then
    iadmin mkuser "$user_name" "$user_type"
  fi
  iadmin moduser "$user_name" password "$password"
}

create_resource() {
  local resource_name="$1"
  local host="$2"
  local vault="$3"

  if ! iadmin lr "$resource_name" >/dev/null 2>&1; then
    iadmin mkresc "$resource_name" unixfilesystem "$host:$vault"
  fi
}

create_user "$IRODS_PRIMARY_TEST_USER" rodsadmin "$IRODS_PRIMARY_TEST_PASSWORD"
create_user "$IRODS_SECONDARY_TEST_USER" rodsuser "$IRODS_SECONDARY_TEST_PASSWORD"
create_user anonymous rodsuser anonymous
iadmin atg public anonymous || true

mkdir -p /var/lib/irods/iRODS/providerVault
create_resource providerResc "$(hostname)" /var/lib/irods/iRODS/providerVault

# resourceResc is created by the consumer setup in resource-entrypoint.sh.

echo "Provider post-setup complete for zone $IRODS_ZONE."
