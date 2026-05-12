#!/usr/bin/env bash
set -euo pipefail

: "${TERMINAL_INIT_IRODS_ENV:=true}"
: "${TERMINAL_IRODS_HOST:=irods-provider}"
: "${TERMINAL_IRODS_PORT:=1247}"
: "${TERMINAL_IRODS_ZONE:=tempZone}"
: "${TERMINAL_IRODS_USER:=rods}"
: "${TERMINAL_IRODS_PASSWORD:=rods}"
: "${TERMINAL_IRODS_AUTH_SCHEME:=native}"
: "${TERMINAL_IRODS_DEFAULT_RESOURCE:=providerResc}"

mkdir -p "$HOME/.irods"

if [ "$TERMINAL_INIT_IRODS_ENV" = "true" ]; then
  if ! drscmd iinit \
    -h "$TERMINAL_IRODS_HOST" \
    -o "$TERMINAL_IRODS_PORT" \
    -u "$TERMINAL_IRODS_USER" \
    -z "$TERMINAL_IRODS_ZONE" \
    -p "$TERMINAL_IRODS_PASSWORD" \
    -t "$TERMINAL_IRODS_AUTH_SCHEME" >/dev/null 2>&1; then
    cat > "$HOME/.irods/irods_environment.json" <<EOF
{
  "irods_host": "$TERMINAL_IRODS_HOST",
  "irods_port": $TERMINAL_IRODS_PORT,
  "irods_user_name": "$TERMINAL_IRODS_USER",
  "irods_zone_name": "$TERMINAL_IRODS_ZONE",
  "irods_user_password": "$TERMINAL_IRODS_PASSWORD",
  "irods_authentication_scheme": "$TERMINAL_IRODS_AUTH_SCHEME",
  "irods_default_resource": "$TERMINAL_IRODS_DEFAULT_RESOURCE",
  "irods_client_server_policy": "CS_NEG_DONT_CARE"
}
EOF
  fi
fi

exec "$@"
