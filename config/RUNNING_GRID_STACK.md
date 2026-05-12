# Running The Grid Stack

This stack uses the repository-root `.env` file as the operator-facing runtime
contract. The YAML and JSON files in `config/` remain the structured service
defaults for REST, DRS, Keycloak, Starbase, and S3.

## Quick Start

The default backend grid starts the provider, resource server, Keycloak, and
both S3 API endpoints. The `frontend` profile adds provider REST, resource REST,
DRS, and Starbase.

```bash
cp .env.example .env
docker compose --profile frontend config --quiet
docker compose --profile frontend pull irods-go-rest-provider irods-go-rest-resource irods-go-drs starbase irods-s3-api-provider irods-s3-api-resource
docker compose --profile frontend build keycloak irods-provider irods-resource
docker compose --profile frontend up -d --build
```

If you are testing locally rebuilt REST or DRS images, set
`IRODS_GO_REST_IMAGE` and `IRODS_GO_DRS_IMAGE` in `.env` to those image tags
before running `up`.

For a backend-only development grid, omit the `frontend` profile:

```bash
docker compose up -d --build
```

To stop and restart the full stack without deleting persisted database/iRODS
state:

```bash
docker compose --profile frontend down
docker compose --profile frontend up -d --build --force-recreate
```

To reset all persisted state after bootstrap/config changes:

```bash
docker compose --profile frontend down --volumes
docker compose --profile frontend up -d --build
```

## Root Environment

Start with `.env.example` and edit `.env` for local differences:

```dotenv
IRODS_ZONE=tempZone
IRODS_ADMIN_USER=rods
IRODS_ADMIN_PASSWORD=rods

IRODS_GO_REST_IMAGE=ghcr.io/michael-conway/irods-go-rest:latest
IRODS_GO_DRS_IMAGE=ghcr.io/michael-conway/irods-go-drs:latest
STARBASE_IMAGE=ghcr.io/michael-conway/starbase:develop
TERMINAL_IMAGE=irods-grid-terminal:local
IRODS_S3_API_IMAGE=irods/irods_s3_api:latest

REST_PROVIDER_HOST_PORT=8080
REST_RESOURCE_HOST_PORT=8082
STARBASE_HOST_PORT=8081
DRS_HOST_PORT=8888
KEYCLOAK_HTTPS_HOST_PORT=8443
KEYCLOAK_MANAGEMENT_HOST_PORT=19090
S3_PROVIDER_HOST_PORT=9001
S3_RESOURCE_HOST_PORT=9002

DRS_API_CLIENT_SECRET=change-me
IRODS_REST_WEB_CLIENT_SECRET=change-me
OIDC_INTERNAL_URL=https://keycloak:8443
OIDC_INSECURE_SKIP_VERIFY=true
```

Do not commit `.env`; it can contain local secrets. The checked-in
`.env.example` documents the full current set of supported variables.

Keycloak is built locally as `irods-grid-keycloak:latest` from
`config/keycloak/Dockerfile-keycloak`. It includes a development self-signed
certificate and listens on HTTPS port `8443`; `KEYCLOAK_IMAGE` is intentionally
not an operator override.

## Config Files

These files are intentionally checked in as runnable defaults:

| File | Purpose |
| --- | --- |
| `config/irods-go-rest/provider.yaml` | Provider-side REST defaults. Compose overrides credentials, OIDC, and public URL from `.env`. |
| `config/irods-go-rest/resource.yaml` | Resource-side REST defaults used with the `frontend` profile. |
| `config/irods-go-drs/drs-config.yaml` | DRS defaults, access-method settings, and resource affinity maps. Compose overrides credentials and core OIDC values from `.env`. |
| `config/irods-go-drs/service-info.json` | DRS service-info metadata mounted at `/etc/irods-grid/service-info.json`. |
| `config/keycloak/realm-drs.json` | Keycloak realm import. Client IDs and secrets are substituted from Keycloak environment variables. |
| `config/keycloak/Dockerfile-keycloak` | Local Keycloak image build with the development HTTPS keystore for port `8443`. |
| `config/s3/provider.json` | Provider-side iRODS S3 API config template. |
| `config/s3/resource.json` | Resource-side iRODS S3 API config template for the `9002` endpoint. |
| `config/starbase/starbase.yaml` | Starbase runtime UI config. |

Both S3 API instances mount `state/shared-s3/` at `/shared-s3-config` and use
the same `irods-s3-bucket-mapping.json` and `irods-s3-user-mapping.json` files.
The provider instance maps to host port `9001`; the resource instance maps to
host port `9002`. The provider S3 API region is `providerResc`, and the
resource-server S3 API region is `resourceResc`, matching the iRODS resource
behind each endpoint. The resource-side S3 API waits for `irods-resource` to
become healthy before starting.

The default backend grid bootstraps `irods-provider` with `providerResc` and
`irods-resource` as an iRODS consumer/resource server for the provider. The
resource-server resource name defaults to `resourceResc`, and the compose health
check uses the generated iRODS admin environment inside the resource container.
The provider entrypoint starts iRODS through the iRODS Python controller so
provider-side replica trim/replicate calls can authenticate with the resource
server correctly.

Frontend services are intentionally profiled:

| Profile | Services |
| --- | --- |
| `frontend` | `irods-go-rest-provider`, `irods-go-rest-resource`, `irods-go-drs`, `starbase` |

If you change host ports in `.env`, also review the URLs in
`config/irods-go-drs/drs-config.yaml`, especially `HttpsResourceAffinity` and
`S3ResourceAffinity`. Those affinity arrays are structured config rather than
simple scalar environment overrides. Treat `S3ResourceAffinity` as placeholder
shape until live `resourceResc` replica-placement tests confirm the S3 endpoint
selection design.

## Terminal Container

The `terminal` service is an on-demand tools shell. It builds a local image with
both `gocmd` and `drscmd` installed on `PATH`.

Build it once:

```bash
docker compose build terminal
```

Open an interactive shell:

```bash
docker compose run --rm terminal
```

Run one-off commands:

```bash
docker compose run --rm terminal gocmd ls /tempZone/home
docker compose run --rm terminal drscmd drsls /tempZone/home/test1
```

At startup, the entrypoint writes a standard iRODS environment for
`irods-provider:1247` using the `TERMINAL_IRODS_*` values from `.env`. The
default user is `rods` in `tempZone`.

## Current Defaults

Default public endpoints:

| Service | URL |
| --- | --- |
| Provider REST | `http://127.0.0.1:8080` |
| Resource REST | `http://127.0.0.1:8082` |
| Starbase | `http://127.0.0.1:8081` |
| DRS | `http://127.0.0.1:8888` |
| Keycloak | `https://127.0.0.1:8443` |
| Provider S3 API | `http://127.0.0.1:9001` |
| Resource S3 API | `http://127.0.0.1:9002` |

## AWS S3 Profiles

The S3 API uses the shared user mapping in
`state/shared-s3/irods-s3-user-mapping.json`. With the current local `test1`
mapping, these AWS CLI files connect to the provider-backed and resource-backed
S3 API endpoints.

`~/.aws/config`:

```ini
[profile irods-grid-provider-s3]
region = providerResc
output = json
endpoint_url = http://127.0.0.1:9001
s3 =
    addressing_style = path

[profile irods-grid-resource-s3]
region = resourceResc
output = json
endpoint_url = http://127.0.0.1:9002
s3 =
    addressing_style = path
```

`~/.aws/credentials`:

```ini
[irods-grid-provider-s3]
aws_access_key_id = test1
aws_secret_access_key = 6q-8dM76UICe0a-Hzkc1X~OdocGoaTlBvZgu6Fg5

[irods-grid-resource-s3]
aws_access_key_id = test1
aws_secret_access_key = 6q-8dM76UICe0a-Hzkc1X~OdocGoaTlBvZgu6Fg5
```

Example checks:

```bash
aws --profile irods-grid-provider-s3 s3api list-buckets
aws --profile irods-grid-provider-s3 s3api list-objects-v2 --bucket testdrssingle
aws --profile irods-grid-resource-s3 s3api list-buckets
aws --profile irods-grid-resource-s3 s3api list-objects-v2 --bucket testdrssingle
```

If your AWS CLI version does not honor `endpoint_url` from the profile, pass
`--endpoint-url http://127.0.0.1:9001` or
`--endpoint-url http://127.0.0.1:9002` on the command line.

Default internal service names used by config files:

| Name | Role |
| --- | --- |
| `postgres` | PostgreSQL database host |
| `irods-provider` | iRODS catalog provider |
| `irods-resource` | iRODS resource server |
| `keycloak` | OIDC issuer for REST and DRS |

## Smoke Checks

After `docker compose --profile frontend up -d --build`, check the public
service ports:

```bash
docker compose --profile frontend ps

curl -k -fsS https://127.0.0.1:8443/realms/drs/.well-known/openid-configuration
curl -fsS http://127.0.0.1:8080/healthz
curl -fsS http://127.0.0.1:8082/healthz
curl -fsS http://127.0.0.1:8080/openapi.yaml | grep 'url: http://127.0.0.1:8080'
curl -fsS http://127.0.0.1:8082/openapi.yaml | grep 'url: http://127.0.0.1:8082'
curl -fsS http://127.0.0.1:8888/swagger | grep 'url: "/openapi.yaml"'
curl -fsS http://127.0.0.1:8888/openapi.yaml | grep 'default: 127.0.0.1:8888'
curl -fsS http://127.0.0.1:8888/ga4gh/drs/v1/service-info | grep 'iRODS Grid Stack DRS'
docker compose --profile frontend logs --tail=80 irods-s3-api-provider irods-s3-api-resource | grep 'Server is ready'
docker compose --profile frontend exec -T irods-provider bash -lc 'printf "%s\n" "$IRODS_ADMIN_PASSWORD" | IRODS_ENVIRONMENT_FILE=/var/lib/irods/.irods/irods_environment.json iinit >/dev/null && IRODS_ENVIRONMENT_FILE=/var/lib/irods/.irods/irods_environment.json iadmin lr providerResc && IRODS_ENVIRONMENT_FILE=/var/lib/irods/.irods/irods_environment.json iadmin lr resourceResc'
docker compose --profile frontend exec -T irods-resource bash -lc 'IRODS_ENVIRONMENT_FILE=/root/.irods/irods_environment.json iadmin lr resourceResc'
```

Keycloak uses a self-signed development certificate, so host-side checks need
`curl -k` unless the certificate is trusted locally. Browsers will show the
normal certificate warning for `https://localhost:8443`.
