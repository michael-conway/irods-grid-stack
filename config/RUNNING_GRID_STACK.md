# Running The Grid Stack

This stack uses the repository-root `.env` file as the operator-facing runtime
contract. The YAML and JSON files in `config/` remain the structured service
defaults for REST, DRS, Keycloak, Starbase, and S3.

## Quick Start

```bash
cp .env.example .env
docker compose pull irods-go-rest-provider irods-go-drs starbase
docker compose build irods-provider
docker compose up postgres irods-provider keycloak
docker compose up irods-go-rest-provider starbase irods-go-drs
```

The resource-server profile is still under validation:

```bash
docker compose --profile resource-server up
```

To pre-pull the resource-side REST image, include the profile:

```bash
docker compose --profile resource-server pull irods-go-rest-resource
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
IRODS_S3_API_IMAGE=irods-s3-api-runner:latest

REST_PROVIDER_HOST_PORT=8080
STARBASE_HOST_PORT=8081
DRS_HOST_PORT=8888
KEYCLOAK_HTTPS_HOST_PORT=8443

DRS_API_CLIENT_SECRET=change-me
IRODS_REST_WEB_CLIENT_SECRET=change-me
```

Do not commit `.env`; it can contain local secrets. The checked-in
`.env.example` documents the full current set of supported variables.

## Config Files

These files are intentionally checked in as runnable defaults:

| File | Purpose |
| --- | --- |
| `config/irods-go-rest/provider.yaml` | Provider-side REST defaults. Compose overrides credentials, OIDC, and public URL from `.env`. |
| `config/irods-go-rest/resource.yaml` | Resource-side REST defaults used with the `resource-server` profile. |
| `config/irods-go-drs/drs-config.yaml` | DRS defaults, access-method settings, and resource affinity maps. Compose overrides credentials and core OIDC values from `.env`. |
| `config/keycloak/realm-drs.json` | Keycloak realm import. Client IDs and secrets are substituted from Keycloak environment variables. |
| `config/s3/provider.json` | Provider-side iRODS S3 API defaults. |
| `config/s3/resource.json` | Resource-side iRODS S3 API defaults used with the `resource-server` profile. |
| `config/starbase/starbase.yaml` | Starbase runtime UI config. |

If you change host ports in `.env`, also review the URLs in
`config/irods-go-drs/drs-config.yaml`, especially `HttpsResourceAffinity` and
`S3ResourceAffinity`. Those affinity arrays are structured config rather than
simple scalar environment overrides.

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

Default internal service names used by config files:

| Name | Role |
| --- | --- |
| `postgres` | PostgreSQL database host |
| `irods-provider` | iRODS catalog provider |
| `irods-resource` | iRODS resource server |
| `keycloak` | OIDC issuer for REST and DRS |

## Resetting State

The database and iRODS server state live in Docker volumes. To reset the local
stack after changing database bootstrap values:

```bash
docker compose down --volumes
docker compose up postgres irods-provider keycloak
```
