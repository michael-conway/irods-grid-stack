#!/usr/bin/env bash
set -euo pipefail

: "${IRODS_ZONE:=tempZone}"
: "${IRODS_ADMIN_USER:=rods}"
: "${IRODS_ADMIN_PASSWORD:=rods}"
: "${IRODS_HOSTNAME:=irods-resource}"
: "${IRODS_PROVIDER_HOST:=irods-provider}"
: "${IRODS_VAULT_DIR:=/var/lib/irods/iRODS/Vault}"

cat <<'MSG'
Resource-server bootstrap is intentionally staged.

This container has the iRODS packages needed for a resource-server role, but the
consumer setup JSON still needs live validation for iRODS 5.x before it should
be allowed to silently claim success.

Expected final behavior:
  1. configure this host as a consumer/resource server for tempZone
  2. point catalog_provider_hosts at irods-provider
  3. start iRODS services
  4. let provider-side setup register resourceResc on irods-resource

See docs/OPEN_ITEMS.md.
MSG

mkdir -p "$IRODS_VAULT_DIR" /var/run/irods
chown -R irods:irods /var/lib/irods /var/run/irods

sleep infinity

