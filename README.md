# iRODS Grid Stack

Docker Compose workspace for running a local multi-server iRODS grid with the
Gabble services around it.

This is not an application source repo. It is the integration environment that
wires the grid and service containers together.

## Target Topology

- PostgreSQL hosts the iRODS catalog and Keycloak databases.
- `irods-provider` is the catalog provider for `tempZone`.
- `irods-resource` is a separate iRODS server joined to the same zone and used
  as a resource host.
- `irods-go-rest-provider` connects to the provider host.
- `irods-go-rest-resource` connects to the resource host.
- `starbase` points at the provider-side REST API by default.
- `irods-s3-api-provider` exposes S3 access for provider-hosted bucket mappings.
- `irods-s3-api-resource` exposes S3 access for resource-hosted bucket mappings.
- `irods-go-drs` exposes DRS for the zone and advertises HTTPS/S3 access
  methods.
- `keycloak` provides the current DRS realm configuration.
- `terminal` is an on-demand shell with `gocmd` and `drscmd` on `PATH`.

## Current State

This is a skeleton project for capturing decisions and iterating toward a
fully bootable stack. The provider setup is owned locally under `./irods`. The
resource-server join flow is represented as a first-class script but still
needs live validation against the selected iRODS 5 package behavior.

The iRODS S3 API services assume a locally available runner image named
`irods-s3-api-runner:latest`. See `docs/OPEN_ITEMS.md`.

The `irods-go-rest`, `irods-go-drs`, and `starbase` services pull image names
from `.env.example` defaults and can be retargeted with `IRODS_GO_REST_IMAGE`,
`IRODS_GO_DRS_IMAGE`, and `STARBASE_IMAGE`.

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
docker compose pull irods-go-rest-provider irods-go-drs starbase
docker compose build irods-provider
docker compose up
```

Use targeted startup while the resource-server bootstrap is being finalized:

```bash
docker compose up postgres irods-provider keycloak
docker compose up irods-go-rest-provider starbase irods-go-drs
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

## Decision Records

Start with:

- [config/RUNNING_GRID_STACK.md](config/RUNNING_GRID_STACK.md)
- `docs/ARCHITECTURE.md`
- `docs/DECISIONS.md`
- `docs/OPEN_ITEMS.md`
