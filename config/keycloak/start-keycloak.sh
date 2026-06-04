#!/bin/bash
set -euo pipefail

# Keep realm configuration (including client secrets) aligned with the import file.
import_args=(import --dir /opt/keycloak/data/import --override true)
if [[ -n "${KC_DB:-}" ]]; then
  import_args+=(--db "${KC_DB}")
fi
if [[ -n "${KC_DB_URL:-}" ]]; then
  import_args+=(--db-url "${KC_DB_URL}")
fi
if [[ -n "${KC_DB_USERNAME:-}" ]]; then
  import_args+=(--db-username "${KC_DB_USERNAME}")
fi
if [[ -n "${KC_DB_PASSWORD:-}" ]]; then
  import_args+=(--db-password "${KC_DB_PASSWORD}")
fi

/opt/keycloak/bin/kc.sh "${import_args[@]}"

exec /opt/keycloak/bin/kc.sh start-dev --import-realm
