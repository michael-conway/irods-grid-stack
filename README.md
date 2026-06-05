# iRODS Grid Stack

Docker Compose workspace for running a local multi-server iRODS grid with REST, DRS, S3 and Starbase services around it.
The grid is used for demo purposes and is not intended for production use. The
default Compose stack starts the base services: iRODS provider, iRODS resource
server, Keycloak, and both S3 API endpoints. The `frontend` profile starts REST,
DRS, and Starbase together. The `rest`, `drs`, `starbase`, and `tools` profiles
can be used independently during development.

A Terminal container is also provided to run the `gocmd` and `drscmd` commands.

## Target Topology

- PostgreSQL hosts the iRODS catalog and Keycloak databases.
- `irods-provider` is the catalog provider for `tempZone`.
- `irods-resource` is a separate iRODS server joined to the same zone and used
  as a resource host.
- `irods-go-rest-provider` connects to the provider host.
- `irods-go-rest-resource` connects to the resource host.
- `starbase` points at the provider-side REST API by default.
  It is configured for direct Keycloak PKCE login using the `drs` realm.
- `starbase` points at the provider-side REST API by default through
  `STARBASE_REST_API_BASE_URL`, aligned with `REST_PROVIDER_PUBLIC_URL`.
- `irods-s3-api-provider` exposes S3 access on host port `9001`.
- `irods-s3-api-resource` exposes a second S3 endpoint on host port `9002`.
- `irods-go-drs` exposes DRS for the zone and advertises HTTPS/S3 access
  methods.
- `keycloak` provides the current DRS realm configuration.
- `terminal` is an on-demand shell with `gocmd` and `drscmd` on `PATH`.

## Current State

The provider and resource server setup are owned locally under `./irods`. The
provider post-setup registers `providerResc`, and the resource server joins the
provider as an iRODS 5 catalog consumer and registers `resourceResc` on
`irods-resource`.

The iRODS S3 API services use `irods/irods_s3_api:0.5.0` by default and share
the bucket and user mapping files under `state/shared-s3/`. The provider S3 API
uses region `providerResc`; the resource-server S3 API uses region
`resourceResc`.

The `irods-go-rest`, `irods-go-drs`, and `starbase` services pull image names
from `.env.example` defaults and can be retargeted with `IRODS_GO_REST_IMAGE`,
`IRODS_GO_DRS_IMAGE`, and `STARBASE_IMAGE`. REST, DRS, and Starbase are behind
optional profiles so the compose file can also run as a backend-only
development grid.

Starbase is served from its own host port and calls provider REST from the
browser. Set `STARBASE_REST_API_BASE_URL` to the browser-facing provider REST
URL and keep `REST_CORS_ALLOWED_ORIGINS` aligned with the Starbase browser
origins. Compose passes `REST_CORS_ALLOWED_ORIGINS` through to both REST
instances as `GOREST_CORS_ALLOWED_ORIGINS`. The default includes the
containerized Starbase origin on port `8081` and the Vite dev server origin on
port `5173`, for both `localhost` and `127.0.0.1`. The container startup script
also generates the Starbase OIDC settings from `STARBASE_OIDC_*` values so the
demo config matches the imported Keycloak Starbase client.

Runtime environment and config-file guidance starts in
[config/RUNNING_GRID_STACK.md](config/RUNNING_GRID_STACK.md).

## Layout

```text
.
├── compose.yaml
├── config/
│   ├── RUNNING_GRID_STACK.md
│   ├── irods-go-drs/
│   ├── irods-go-rest/
│   ├── keycloak/
│   ├── s3/
│   └── starbase/
├── docs/
├── irods/
│   ├── Dockerfile.provider
│   ├── Dockerfile.resource
│   ├── docker-entrypoint.sh
│   ├── provider-postsetup.sh
│   ├── resource-entrypoint.sh
│   └── testsetup-consortium.sh
├── scripts/
├── terminal/
└── state/
```

## First Commands

```bash
cp .env.example .env
docker compose --profile frontend config --quiet
docker compose --profile frontend up -d --build
```

`starbase` can point at any browser-reachable REST URL through
`STARBASE_REST_API_BASE_URL`. Use `--profile rest --profile starbase` for the
usual local Starbase plus provider REST pairing.

Run only REST APIs:

```bash
docker compose --profile rest up -d --build
```

Run only DRS:

```bash
docker compose --profile drs up -d --build
```

Run a backend-only development grid by omitting the `frontend` profile:

```bash
docker compose up -d --build
```

Open the CLI terminal:

```bash
docker compose build terminal
docker compose run --rm terminal
```

## Default Host Ports

- iRODS provider: `1247`
- iRODS resource server: `2247`
- Provider REST: `8080`
- Resource REST: `8082`
- Starbase: `8081`
- DRS: `8888`
- Keycloak: `8443`
- Provider S3 API: `9001`
- Resource S3 API: `9002`

## Tips

If network errors occur, check for stale containers. A targeted recreate often clears up network issues in the development environment.

```aiignore
docker compose --profile frontend down --remove-orphans
docker compose --profile frontend up -d --build
```

## Decision Records

## OIDC Notes

Keycloak realm import includes:

- confidential REST web-login client (`irods-go-rest`) for `/web/login`
- public Starbase SPA client (`starbase-spa`) for direct PKCE redirects:
  - `http://localhost:8081/auth/callback` (compose Starbase)
  - `http://localhost:5173/auth/callback` (local Starbase dev mode)

Start with:

- [config/RUNNING_GRID_STACK.md](config/RUNNING_GRID_STACK.md)
- `docs/ARCHITECTURE.md`
- `docs/DECISIONS.md`
- `docs/OPEN_ITEMS.md`
