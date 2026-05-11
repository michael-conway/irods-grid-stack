# Open Items

## iRODS resource server bootstrap

The provider Docker entrypoint originated from the DRS framework and is now
owned in this repo. The resource-server join flow still needs live validation
for iRODS 5.x. The intended model is:

1. provider initializes first
2. resource server starts with `catalog_service_role=consumer`
3. provider registers `resourceResc` using `irods-resource` as the resource host

## iRODS S3 API image

This skeleton expects an image named `irods-s3-api-runner:latest`. Add one of:

- a checked-in build context for the iRODS S3 API package
- a documented external image
- a compose profile that builds the package from a sibling checkout

## DRS S3 resource affinity

`irods-go-drs` currently has a TODO in S3 access-method construction for
resource affinity. This stack captures the desired shape with
`S3ResourceAffinity`, but DRS still needs to choose provider/resource S3
endpoint metadata per replica resource.

## Health checks

Add health checks for:

- provider iRODS readiness
- resource iRODS readiness
- REST `/api/v1/health`
- DRS `/service-info`
- S3 API list-buckets smoke check
