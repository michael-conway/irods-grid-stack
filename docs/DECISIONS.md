# Decisions

## 1. Keep this as a separate integration project

The Docker grid spans several repos and generated images. Keeping it in its own
project avoids coupling application source trees to local orchestration state.

## 2. Use one iRODS zone with two iRODS servers

`irods-provider` is the catalog provider. `irods-resource` joins as a separate
server in the same zone and hosts `resourceResc`.

This is better for testing than two independent zones because DRS, REST,
Starbase, and the S3 API all exercise a single catalog with multiple physical
resource locations.

## 3. Run REST on both iRODS hosts

Provider-side REST and resource-side REST are both useful:

- provider REST is the default UI/API endpoint
- resource REST tests colocated access and HTTPS access-method affinity

## 4. Split S3 bucket mapping by S3 API instance

The S3 API local-file bucket mapper is process-local. Each S3 API instance gets
its own bucket mapping file:

- provider bucket mapping: `/shared-s3/provider/irods-s3-bucket-mapping.json`
- resource bucket mapping: `/shared-s3/resource/irods-s3-bucket-mapping.json`

The user mapping file is shared:

- `/shared-s3/irods-s3-user-mapping.json`

## 5. Treat regions as endpoint identity

The provider and resource S3 API instances use different region names:

- `tempzone-provider`
- `tempzone-resource`

This makes AWS profile/client behavior explicit even though both endpoints
present data from the same iRODS zone.

## 6. Use host-reachable URLs in returned access methods

DRS access URLs should be usable by clients outside Docker. Config files should
therefore use `http://127.0.0.1:<port>` for public URLs and access URLs unless
the caller is explicitly testing container-internal clients.

