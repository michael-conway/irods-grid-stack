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

The provider is the catalog provider and owns the ICAT connection. The resource
server joins the same zone as a separate iRODS server. The provider setup script
creates local provider resources and registers a remote unixfilesystem resource
hosted by `irods-resource`.

Initial resource names:

- `providerResc`
- `resourceResc`

## REST

Two REST instances are deliberate:

- Provider REST validates the common user/admin workflows against the catalog
  provider.
- Resource REST validates direct API behavior when the API is colocated with a
  resource host.

Both share the same S3 user mapping file. Each has its own bucket mapping file
so the provider and resource S3 API instances can be tested independently.

## S3

The S3 API is deployed twice:

- `irods-s3-api-provider`, host port `9001`, region `tempzone-provider`
- `irods-s3-api-resource`, host port `9002`, region `tempzone-resource`

Both instances share user credentials but use separate bucket mapping JSON
files. This mirrors the desired AWS client shape: two endpoints/regions
pointing at the same iRODS zone.

## DRS

DRS runs once per zone. It points at the provider host for metadata/catalog
operations and advertises:

- HTTPS access methods through the REST instances using resource affinity.
- S3 access methods for bucket-marked collections.

The current DRS code has an explicit TODO for S3 resource affinity. The stack
captures the desired config shape now so the application change can follow.

## Starbase

Starbase runs from the published `ghcr.io/michael-conway/starbase` image and
points at the provider REST instance by default. It enables S3 admin UI through
runtime config.

## Terminal

The terminal service is an on-demand tools container with `gocmd` and `drscmd`
on `PATH`. It is not part of the default long-running stack; use
`docker compose run --rm terminal` to inspect or administer the grid from inside
the compose network.
