# Open Items

## DRS S3 resource affinity

`irods-go-drs` currently has a TODO in S3 access-method construction for
resource affinity. Defer final S3 resource-affinity decisions until
`resourceResc` live replica-placement tests verify the S3 endpoint-selection
design rather than just the configuration shape.

The checked-in `S3ResourceAffinity` values are placeholders for that later
verification pass. The S3 API endpoint regions are already aligned with the
backing iRODS resource names: `providerResc` and `resourceResc`.

## End-to-end smoke automation

Compose now has container-level health checks for the demo services. The next
step is to automate the host-facing checks from `config/RUNNING_GRID_STACK.md`
so CI or a release script can verify:

- public REST and DRS endpoints
- Starbase runtime config and OIDC callback settings
- S3 API list-buckets against both provider and resource endpoints
