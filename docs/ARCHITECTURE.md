# Architecture

## Service Graph

```text
                    ┌──────────────┐
                    │   keycloak   │
                    └──────┬───────┘
                           │ OIDC
┌────────────┐      ┌──────▼───────┐
│ postgres   │◄────►│ irods-go-drs │
└─────┬──────┘      └──────┬───────┘
      │                    │ DRS access methods
      │                    │
┌─────▼──────────┐   ┌─────▼────────────────┐
│ irods-provider │◄──┤ irods-go-rest-provider│◄──┐
└─────┬──────────┘   └──────────┬───────────┘   │
      │                         │               │
      │ provider resource       │               │
      │                         │               │
┌─────▼──────────┐   ┌──────────▼───────────┐   │
│ irods-resource │◄──┤ irods-go-rest-resource│   │
└─────┬──────────┘   └──────────┬───────────┘   │
      │                         │               │
      │                         └───────────────┤
      │                                         │
┌─────▼────────────────┐   ┌────────────────────▼┐
│ irods-s3-api-provider│   │ irods-s3-api-resource│
└──────────────────────┘   └─────────────────────┘
                 ▲
                 │ browser
             ┌───┴────┐
             │starbase│
             └────────┘

             ┌────────┐
             │terminal│
             └────────┘
```

## iRODS

The provider is the catalog provider and owns the ICAT connection. Provider
post-setup registers `providerResc` on `irods-provider`. The resource server
joins the same zone as a separate iRODS server and registers a local
unixfilesystem resource hosted by `irods-resource`.

Initial resource names:

- `providerResc`
- `resourceResc`

## REST

Two REST instances are deliberate:

- Provider REST validates the common user/admin workflows against the catalog
  provider.
- Resource REST validates direct API behavior when the API is colocated with a
  resource host.

Both REST instances use the same S3 bucket and user mapping files as the S3 API
instances so REST-admin changes are visible to both S3 endpoints.

Both REST services are in the `frontend` compose profile so the default compose
stack can start only the backend iRODS/S3 services for development.

## S3

The S3 API is deployed twice:

- `irods-s3-api-provider`, host port `9001`, region `providerResc`
- `irods-s3-api-resource`, host port `9002`, region `resourceResc`

Both instances use the same shared bucket mapping JSON and the same shared user
mapping JSON. This mirrors the desired AWS client shape: two endpoints whose
regions identify the backing iRODS resource while they share one iRODS zone and
mapping state. The provider endpoint
connects to `irods-provider` and uses `providerResc`; the resource endpoint
connects to `irods-resource` and uses `resourceResc`.

Final DRS S3 resource-affinity behavior is intentionally deferred until
live `resourceResc` replica-placement tests verify how DRS should choose
provider/resource S3 endpoint metadata.

## DRS

DRS runs once per zone. It points at the provider host for metadata/catalog
operations and advertises:

- HTTPS access methods through the REST instances using resource affinity.
- S3 access methods for bucket-marked collections.

The DRS service is in the `frontend` compose profile. Its service-info sampler
reads `config/irods-go-drs/service-info.json` from `/etc/irods-grid/` in the
container.

The current DRS code has an explicit TODO for S3 resource affinity. The stack
keeps placeholder S3 affinity config, but final endpoint-selection behavior
should be decided after the resource server is running and can verify the
design with real replica placement.

## Starbase

Starbase runs from the published `ghcr.io/michael-conway/starbase` image and
points at the provider REST instance by default through the
`STARBASE_REST_API_BASE_URL` environment variable. The Starbase container
generates `/var/www/starbase/config/starbase.yaml` at startup and writes that
value as `RestAPIBaseURL`. The URL must be browser-facing, so the default is
`http://127.0.0.1:8080` rather than the Docker-internal
`irods-go-rest-provider:8080` service name. Starbase enables S3 admin UI
through the same generated runtime config. It is in the `frontend` compose
profile.

Because Starbase and REST are separate browser origins in this local stack,
both REST services receive `GOREST_CORS_ALLOWED_ORIGINS` from
`REST_CORS_ALLOWED_ORIGINS`. The default allows `http://localhost:8081` and
`http://127.0.0.1:8081`, matching the default Starbase host port.

## Terminal

The terminal service is an on-demand tools container with `gocmd` and `drscmd`
on `PATH`. It is not part of the default long-running stack; use
`docker compose run --rm terminal` to inspect or administer the grid from inside
the compose network.
