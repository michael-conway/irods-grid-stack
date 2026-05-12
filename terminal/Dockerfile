FROM golang:1.25-alpine AS builder

ARG GOCOMMANDS_REF=latest
ARG IRODS_GO_DRS_REF=develop

RUN apk add --no-cache ca-certificates git

RUN mkdir -p /out \
    && go install github.com/cyverse/gocommands/cmd@${GOCOMMANDS_REF} \
    && mv /go/bin/cmd /out/gocmd

RUN go install github.com/michael-conway/irods-go-drs/tools/drs-console@${IRODS_GO_DRS_REF} \
    && mv /go/bin/drs-console /out/drscmd

FROM alpine:3.22 AS runtime

RUN apk add --no-cache bash ca-certificates curl jq less nano \
    && addgroup -S terminal \
    && adduser -S -G terminal -h /home/terminal -s /bin/bash terminal

COPY --from=builder /out/gocmd /usr/local/bin/gocmd
COPY --from=builder /out/drscmd /usr/local/bin/drscmd
COPY terminal-entrypoint.sh /usr/local/bin/terminal-entrypoint

RUN chmod +x /usr/local/bin/gocmd /usr/local/bin/drscmd /usr/local/bin/terminal-entrypoint

USER terminal
WORKDIR /home/terminal

ENTRYPOINT ["terminal-entrypoint"]
CMD ["bash"]
