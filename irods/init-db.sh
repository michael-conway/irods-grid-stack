#!/usr/bin/env bash
set -euo pipefail

: "${IRODS_DB_NAME:=ICAT}"
: "${IRODS_DB_USER:=irods}"
: "${IRODS_DB_PASSWORD:=testpassword}"
: "${KEYCLOAK_DB_NAME:=KEYCLOAK}"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres \
  -v db_user="$IRODS_DB_USER" \
  -v db_password="$IRODS_DB_PASSWORD" <<'EOSQL'
CREATE USER :"db_user" WITH PASSWORD :'db_password';
EOSQL

createdb --username "$POSTGRES_USER" --owner "$IRODS_DB_USER" "$IRODS_DB_NAME"
createdb --username "$POSTGRES_USER" --owner "$IRODS_DB_USER" "$KEYCLOAK_DB_NAME"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres \
  -v irods_db_name="$IRODS_DB_NAME" \
  -v keycloak_db_name="$KEYCLOAK_DB_NAME" \
  -v db_user="$IRODS_DB_USER" <<'EOSQL'
GRANT ALL PRIVILEGES ON DATABASE :"irods_db_name" TO :"db_user";
ALTER DATABASE :"irods_db_name" OWNER TO :"db_user";
GRANT ALL PRIVILEGES ON DATABASE :"keycloak_db_name" TO :"db_user";
ALTER DATABASE :"keycloak_db_name" OWNER TO :"db_user";
EOSQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$IRODS_DB_NAME" \
  -v db_user="$IRODS_DB_USER" <<'EOSQL'
ALTER SCHEMA public OWNER TO :"db_user";
GRANT ALL ON SCHEMA public TO :"db_user";
EOSQL
