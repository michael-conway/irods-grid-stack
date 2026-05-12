# Decisions

## 1. Keep this as a separate integration project

The Docker grid spans several repos and generated images. Keeping it in its own
project avoids coupling application source trees to local orchestration state.

## 2. Use one iRODS zone with two iRODS servers

`irods-provider` is the catalog provider and hosts `providerResc`.
`irods-resource` joins as a separate server in the same zone and hosts
`resourceResc`.

This is better for testing than two independent zones because DRS, REST,
Starbase, and the S3 API all exercise a single catalog with multiple physical
resource locations.

## 3. Run REST on both iRODS hosts

Provider-side REST and resource-side REST are both useful:

- provider REST is the default UI/API endpoint
- resource REST tests colocated access and HTTPS access-method affinity

## 4. Share S3 mapping files across S3 API instances

The S3 API local-file mappers read JSON files from the shared stack state
directory. Both S3 API instances use the same bucket and user mapping files so
REST admin changes and S3 reads converge on one mapping state:

- bucket mapping: `/shared-s3-config/irods-s3-bucket-mapping.json`
- user mapping: `/shared-s3-config/irods-s3-user-mapping.json`

## 5. Treat regions as endpoint identity

The provider and resource S3 API instances use different region names:

- `tempzone-provider`
- `tempzone-resource`

This makes AWS profile/client behavior explicit even though both endpoints
present data from the same iRODS zone.

The second S3 API instance connects to `irods-resource` and uses
`resourceResc`. This keeps the endpoint topology ready for later S3
resource-affinity tests.

Do not finalize DRS S3 resource-affinity behavior before `resourceResc` replica
placement is tested meaningfully.

## 6. Use host-reachable URLs in returned access methods

DRS access URLs should be usable by clients outside Docker. Config files should
therefore use `http://127.0.0.1:<port>` for public URLs and access URLs unless
the caller is explicitly testing container-internal clients.

## 7. Keep frontend/API services optional

REST, DRS, and Starbase use the `frontend` compose profile. The provider,
resource server, Keycloak, and S3 API endpoints are part of the default compose
stack so `docker compose up` is useful as a backend-only development grid, while
`docker compose --profile frontend up` starts the complete service stack.
