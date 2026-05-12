#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

: "${IRODS_ZONE:=tempZone}"
: "${IRODS_ADMIN_USER:=rods}"
: "${IRODS_ADMIN_PASSWORD:=rods}"
: "${IRODS_HOSTNAME:=irods-resource}"
: "${IRODS_PROVIDER_HOST:=irods-provider}"
: "${IRODS_PROVIDER_PORT:=1247}"
: "${IRODS_RESOURCE_NAME:=${IRODS_RESOURCE_RESOURCE:-resourceResc}}"
: "${IRODS_VAULT_DIR:=/var/lib/irods/iRODS/resourceVault}"
: "${IRODS_ZONE_KEY:=TEMPORARY_ZONE_KEY}"
: "${IRODS_NEGOTIATION_KEY:=32_byte_server_negotiation_key__}"
: "${IRODS_CLIENT_SERVER_POLICY:=CS_NEG_REFUSE}"
: "${IRODS_AUTH_SCHEME:=native}"
: "${IRODS_PORT_RANGE_START:=20000}"
: "${IRODS_PORT_RANGE_END:=20199}"
: "${IRODS_PROVIDER_READY_RETRIES:=90}"
: "${IRODS_READY_RETRIES:=60}"

SETUP_ANSWERS=/tmp/irods_resource_setup_answers.json
PROVIDER_ENV=/tmp/provider_irods_environment.json
IRODS_ENV=/var/lib/irods/.irods/irods_environment.json
ROOT_IRODS_ENV=/root/.irods/irods_environment.json

log() {
  echo "resource-entrypoint: $*"
}

find_setup_py() {
  for path in \
    /var/lib/irods/scripts/setup_irods.py \
    /var/lib/irods/setup_irods.py
  do
    if [ -f "$path" ]; then
      echo "$path"
      return 0
    fi
  done

  log "ERROR: setup_irods.py not found"
  return 1
}

prepare_directories() {
  mkdir -p "$IRODS_VAULT_DIR" /var/run/irods /var/lib/irods/.irods /root/.irods
  chown -R irods:irods /var/lib/irods /var/run/irods
  chmod 775 /var/run/irods
  chmod 700 /root/.irods
}

write_client_environment() {
  local path="$1"
  local host="$2"
  local default_resource="$3"

  CLIENT_ENV_PATH="$path" \
  CLIENT_ENV_HOST="$host" \
  CLIENT_ENV_PORT=1247 \
  CLIENT_ENV_USER="$IRODS_ADMIN_USER" \
  CLIENT_ENV_ZONE="$IRODS_ZONE" \
  CLIENT_ENV_DEFAULT_RESOURCE="$default_resource" \
  CLIENT_ENV_POLICY="$IRODS_CLIENT_SERVER_POLICY" \
  CLIENT_ENV_NEGOTIATION_KEY="$IRODS_NEGOTIATION_KEY" \
    python3 - <<'PY'
import json
import os

config = {
    "irods_host": os.environ["CLIENT_ENV_HOST"],
    "irods_port": int(os.environ["CLIENT_ENV_PORT"]),
    "irods_user_name": os.environ["CLIENT_ENV_USER"],
    "irods_zone_name": os.environ["CLIENT_ENV_ZONE"],
    "irods_default_resource": os.environ["CLIENT_ENV_DEFAULT_RESOURCE"],
    "irods_client_server_policy": os.environ["CLIENT_ENV_POLICY"],
    "irods_client_server_negotiation_key": os.environ["CLIENT_ENV_NEGOTIATION_KEY"],
    "irods_encryption_algorithm": "AES-256-CBC",
    "irods_encryption_key_size": 32,
    "irods_encryption_num_hash_rounds": 16,
    "irods_encryption_salt_size": 8,
}

with open(os.environ["CLIENT_ENV_PATH"], "w", encoding="utf-8") as f:
    json.dump(config, f, indent=4)
    f.write("\n")
PY
}

write_runtime_environments() {
  write_client_environment "$IRODS_ENV" "$IRODS_HOSTNAME" "$IRODS_RESOURCE_NAME"
  write_client_environment "$ROOT_IRODS_ENV" "$IRODS_HOSTNAME" "$IRODS_RESOURCE_NAME"

  chown -R irods:irods /var/lib/irods/.irods
  chmod 600 "$ROOT_IRODS_ENV"

  cat > /var/lib/irods/.bashrc <<EOF
export IRODS_ENVIRONMENT_FILE=$IRODS_ENV
export HOME=/var/lib/irods
EOF
  chown irods:irods /var/lib/irods/.bashrc
}

write_provider_environment() {
  write_client_environment "$PROVIDER_ENV" "$IRODS_PROVIDER_HOST" providerResc
}

wait_for_provider() {
  log "waiting for provider at ${IRODS_PROVIDER_HOST}:${IRODS_PROVIDER_PORT}"
  write_provider_environment

  for i in $(seq 1 "$IRODS_PROVIDER_READY_RETRIES"); do
    if nc -z "$IRODS_PROVIDER_HOST" "$IRODS_PROVIDER_PORT" >/dev/null 2>&1 &&
       printf '%s\n' "$IRODS_ADMIN_PASSWORD" | IRODS_ENVIRONMENT_FILE="$PROVIDER_ENV" iinit >/tmp/provider_iinit.log 2>&1 &&
       IRODS_ENVIRONMENT_FILE="$PROVIDER_ENV" iadmin lr >/dev/null 2>&1; then
      log "provider is ready"
      return 0
    fi

    log "provider not ready yet (${i}/${IRODS_PROVIDER_READY_RETRIES})"
    sleep 2
  done

  log "ERROR: provider did not become ready"
  if [ -f /tmp/provider_iinit.log ]; then
    cat /tmp/provider_iinit.log
  fi
  return 1
}

generate_setup_answers() {
  log "generating iRODS consumer setup answers"

  SETUP_ANSWERS="$SETUP_ANSWERS" \
  IRODS_ZONE="$IRODS_ZONE" \
  IRODS_ADMIN_USER="$IRODS_ADMIN_USER" \
  IRODS_ADMIN_PASSWORD="$IRODS_ADMIN_PASSWORD" \
  IRODS_HOSTNAME="$IRODS_HOSTNAME" \
  IRODS_PROVIDER_HOST="$IRODS_PROVIDER_HOST" \
  IRODS_RESOURCE_NAME="$IRODS_RESOURCE_NAME" \
  IRODS_VAULT_DIR="$IRODS_VAULT_DIR" \
  IRODS_ZONE_KEY="$IRODS_ZONE_KEY" \
  IRODS_NEGOTIATION_KEY="$IRODS_NEGOTIATION_KEY" \
  IRODS_CLIENT_SERVER_POLICY="$IRODS_CLIENT_SERVER_POLICY" \
  IRODS_AUTH_SCHEME="$IRODS_AUTH_SCHEME" \
  IRODS_PORT_RANGE_START="$IRODS_PORT_RANGE_START" \
  IRODS_PORT_RANGE_END="$IRODS_PORT_RANGE_END" \
    python3 - <<'PY'
import json
import os

zone = os.environ["IRODS_ZONE"]
admin_user = os.environ["IRODS_ADMIN_USER"]
resource_name = os.environ["IRODS_RESOURCE_NAME"]
policy = os.environ["IRODS_CLIENT_SERVER_POLICY"]
negotiation_key = os.environ["IRODS_NEGOTIATION_KEY"]

rule_engines = [
    {
        "instance_name": "irods_rule_engine_plugin-irods_rule_language-instance",
        "plugin_name": "irods_rule_engine_plugin-irods_rule_language",
        "plugin_specific_configuration": {
            "re_data_variable_mapping_set": ["core"],
            "re_function_name_mapping_set": ["core"],
            "re_rulebase_set": ["core"],
            "regexes_for_supported_peps": [
                "ac[^ ]*",
                "msi[^ ]*",
                "[^ ]*pep_[^ ]*_(pre|post|except|finally)",
            ],
        },
        "shared_memory_instance": "irods_rule_language_rule_engine",
    },
    {
        "instance_name": "irods_rule_engine_plugin-cpp_default_policy-instance",
        "plugin_name": "irods_rule_engine_plugin-cpp_default_policy",
        "plugin_specific_configuration": {},
    },
]

client_environment = {
    "irods_client_server_policy": policy,
    "irods_connection_pool_refresh_time_in_seconds": 300,
    "irods_cwd": f"/{zone}/home/{admin_user}",
    "irods_default_hash_scheme": "SHA256",
    "irods_default_number_of_transfer_threads": 4,
    "irods_default_resource": resource_name,
    "irods_encryption_algorithm": "AES-256-CBC",
    "irods_encryption_key_size": 32,
    "irods_encryption_num_hash_rounds": 16,
    "irods_encryption_salt_size": 8,
    "irods_home": f"/{zone}/home/{admin_user}",
    "irods_host": os.environ["IRODS_HOSTNAME"],
    "irods_match_hash_policy": "compatible",
    "irods_maximum_size_for_single_buffer_in_megabytes": 32,
    "irods_port": 1247,
    "irods_transfer_buffer_size_for_parallel_transfer_in_megabytes": 4,
    "irods_user_name": admin_user,
    "irods_zone_name": zone,
    "schema_name": "service_account_environment",
    "schema_version": "v5",
}

server_config = {
    "advanced_settings": {
        "checksum_read_buffer_size_in_bytes": 1048576,
        "default_number_of_transfer_threads": 4,
        "default_temporary_password_lifetime_in_seconds": 120,
        "delay_rule_executors": [],
        "delay_server_sleep_time_in_seconds": 30,
        "hostname_cache": {
            "eviction_age_in_seconds": 3600,
            "cache_clearer_sleep_time_in_seconds": 600,
            "shared_memory_size_in_bytes": 2500000,
            "shared_memory_instance": "irods_hostname_cache",
        },
        "dns_cache": {
            "eviction_age_in_seconds": 3600,
            "cache_clearer_sleep_time_in_seconds": 600,
            "shared_memory_size_in_bytes": 5000000,
            "shared_memory_instance": "irods_dns_cache",
        },
        "maximum_size_for_single_buffer_in_megabytes": 32,
        "maximum_size_of_delay_queue_in_bytes": 0,
        "maximum_temporary_password_lifetime_in_seconds": 1000,
        "migrate_delay_server_sleep_time_in_seconds": 5,
        "number_of_concurrent_delay_rule_executors": 4,
        "stacktrace_file_processor_sleep_time_in_seconds": 10,
        "transfer_buffer_size_for_parallel_transfer_in_megabytes": 4,
        "transfer_chunk_size_for_parallel_transfer_in_megabytes": 40,
    },
    "catalog_provider_hosts": [os.environ["IRODS_PROVIDER_HOST"]],
    "catalog_service_role": "consumer",
    "client_server_policy": policy,
    "connection_pool_refresh_time_in_seconds": 300,
    "controlled_user_connection_list": {
        "control_type": "denylist",
        "users": [],
    },
    "default_dir_mode": "0750",
    "default_file_mode": "0600",
    "default_hash_scheme": "SHA256",
    "default_resource_name": resource_name,
    "encryption": {
        "algorithm": "AES-256-CBC",
        "key_size": 32,
        "num_hash_rounds": 16,
        "salt_size": 8,
    },
    "environment_variables": {},
    "federation": [],
    "graceful_shutdown_timeout_in_seconds": 30,
    "host": os.environ["IRODS_HOSTNAME"],
    "host_access_control": {
        "access_entries": [],
    },
    "host_resolution": {
        "host_entries": [],
    },
    "log_level": {
        "agent": "info",
        "agent_factory": "info",
        "api": "info",
        "authentication": "info",
        "database": "info",
        "delay_server": "info",
        "genquery1": "info",
        "genquery2": "info",
        "legacy": "info",
        "microservice": "info",
        "network": "info",
        "resource": "info",
        "rule_engine": "info",
        "server": "info",
        "sql": "info",
    },
    "match_hash_policy": "compatible",
    "negotiation_key": negotiation_key,
    "hostname_cache_shared_memory_name": "irods_hostname_cache",
    "dns_cache_shared_memory_name": "irods_dns_cache",
    "hostname_cache_shm_name": "irods_hostname_cache",
    "dns_cache_shm_name": "irods_dns_cache",
    "plugin_configuration": {
        "authentication": {},
        "network": {},
        "resource": {},
        "rule_engines": rule_engines,
    },
    "rule_engine_namespaces": [""],
    "schema_name": "server_config",
    "schema_version": "v5",
    "server_port_range_start": int(os.environ["IRODS_PORT_RANGE_START"]),
    "server_port_range_end": int(os.environ["IRODS_PORT_RANGE_END"]),
    "zone_auth_scheme": os.environ["IRODS_AUTH_SCHEME"],
    "zone_key": os.environ["IRODS_ZONE_KEY"],
    "zone_name": zone,
    "zone_port": 1247,
    "zone_user": admin_user,
}

answers = {
    "admin_password": os.environ["IRODS_ADMIN_PASSWORD"],
    "default_resource_directory": os.environ["IRODS_VAULT_DIR"],
    "default_resource_name": resource_name,
    "host_system_information": {
        "service_account_user_name": "irods",
        "service_account_group_name": "irods",
    },
    "service_account_environment": client_environment,
    "server_config": server_config,
}

with open(os.environ["SETUP_ANSWERS"], "w", encoding="utf-8") as f:
    json.dump(answers, f, indent=4)
    f.write("\n")
PY
  chown irods:irods "$SETUP_ANSWERS"
  chmod 600 "$SETUP_ANSWERS"
}

run_setup() {
  local setup_py
  setup_py="$(find_setup_py)"

  log "running iRODS consumer setup via $setup_py"
  if python3 "$setup_py" --json_configuration_file "$SETUP_ANSWERS" > /tmp/setup_irods_resource.log 2>&1; then
    log "iRODS consumer setup completed"
    return 0
  fi

  log "ERROR: iRODS consumer setup failed"
  cat /tmp/setup_irods_resource.log
  return 1
}

start_irods() {
  log "starting iRODS services"
  mkdir -p /var/run/irods
  chown irods:irods /var/run/irods
  chmod 775 /var/run/irods

  sudo -u irods env \
    HOME=/var/lib/irods \
    PYTHONPATH=/var/lib/irods/scripts \
    irodsConfigDir=/etc/irods \
    python3 - <<'PY'
from irods.configuration import IrodsConfig
from irods.controller import IrodsController

controller = IrodsController(IrodsConfig())
if controller.get_server_proc() is None:
    controller.start()
else:
    print("iRODS server is already running")
PY
}

init_irods_auth() {
  log "initializing iRODS admin sessions"

  printf '%s\n' "$IRODS_ADMIN_PASSWORD" |
    sudo -u irods env \
      HOME=/var/lib/irods \
      IRODS_ENVIRONMENT_FILE="$IRODS_ENV" \
      iinit

  printf '%s\n' "$IRODS_ADMIN_PASSWORD" |
    IRODS_ENVIRONMENT_FILE="$ROOT_IRODS_ENV" \
      iinit
}

wait_for_local_irods() {
  log "waiting for local resource server readiness"

  for i in $(seq 1 "$IRODS_READY_RETRIES"); do
    if IRODS_ENVIRONMENT_FILE="$ROOT_IRODS_ENV" iadmin lr >/dev/null 2>&1; then
      log "resource server is ready"
      return 0
    fi

    log "resource server not ready yet (${i}/${IRODS_READY_RETRIES})"
    sleep 2
  done

  log "ERROR: resource server did not become ready"
  return 1
}

tail_logs() {
  local rodslog_file=
  local log_paths=(
    "/var/lib/irods/log/irods.log"
    "/var/lib/irods/log/rodsLog"
    "/var/lib/irods/iRODS/server/log/rodsLog"
  )

  for path in "${log_paths[@]}"; do
    if [ -f "$path" ]; then
      rodslog_file="$path"
      break
    fi
  done

  if [ -z "$rodslog_file" ]; then
    mkdir -p /var/lib/irods/log
    touch /var/lib/irods/log/irods.log
    chown -R irods:irods /var/lib/irods/log
    rodslog_file=/var/lib/irods/log/irods.log
  fi

  log "tailing $rodslog_file"
  tail -F "$rodslog_file"
}

main() {
  prepare_directories

  if [ -f /etc/irods/server_config.json ]; then
    log "existing iRODS resource-server configuration found"
    write_runtime_environments
    start_irods
    init_irods_auth
    wait_for_local_irods
    tail_logs
    return 0
  fi

  wait_for_provider
  generate_setup_answers
  run_setup
  write_runtime_environments
  start_irods
  init_irods_auth
  wait_for_local_irods

  log "iRODS resource server initialized for $IRODS_ZONE using $IRODS_RESOURCE_NAME"
  tail_logs
}

main "$@"
