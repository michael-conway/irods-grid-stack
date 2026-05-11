FROM --platform=linux/amd64 ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV IRODS_VERSION=5.0.3

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      wget gnupg ca-certificates lsb-release netcat-openbsd iproute2 procps \
      tzdata python3-pip python3-setuptools sudo curl net-tools \
    && groupadd -r irods \
    && useradd -r -g irods -m -d /var/lib/irods -s /bin/bash irods \
    && curl -fsSL https://packages.irods.org/irods-signing-key.asc \
      | gpg --dearmor -o /usr/share/keyrings/irods-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/irods-archive-keyring.gpg] https://packages.irods.org/apt/ $(lsb_release -sc) main" \
      > /etc/apt/sources.list.d/renci-irods.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends irods-server irods-runtime irods-icommands \
    && mkdir -p /var/run/irods \
    && chown irods:irods /var/run/irods \
    && chmod 775 /var/run/irods \
    && rm -rf /var/lib/apt/lists/*

COPY resource-entrypoint.sh /usr/local/sbin/resource-entrypoint.sh
RUN chmod +x /usr/local/sbin/resource-entrypoint.sh

EXPOSE 1247 1248 20000-20199/tcp

VOLUME ["/var/lib/irods", "/etc/irods"]

ENTRYPOINT ["/usr/local/sbin/resource-entrypoint.sh"]

