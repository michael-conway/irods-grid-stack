# Open Items

## DRS S3 resource affinity

`irods-go-drs` currently has a TODO in S3 access-method construction for
resource affinity. Defer final S3 resource-affinity decisions until
`resourceResc` live replica-placement tests verify the S3 endpoint-selection
design rather than just the configuration shape.

The checked-in `S3ResourceAffinity` values are placeholders for that later
verification pass.

## Health checks

Add health checks for:

- provider iRODS readiness
- provider REST `/healthz`
- resource REST `/healthz`
- DRS `/ga4gh/drs/v1/service-info`
- S3 API list-buckets smoke check
