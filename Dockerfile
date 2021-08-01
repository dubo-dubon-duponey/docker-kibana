ARG           FROM_REGISTRY=ghcr.io/dubo-dubon-duponey

ARG           FROM_IMAGE_BUILDER=base:builder-bullseye-2021-07-01@sha256:f1c46316c38cc1ca54fd53b54b73797b35ba65ee727beea1a5ed08d0ad7e8ccf
ARG           FROM_IMAGE_RUNTIME=base:runtime-bullseye-2021-07-01@sha256:9f5b20d392e1a1082799b3befddca68cee2636c72c502aa7652d160896f85b36
ARG           FROM_IMAGE_TOOLS=tools:linux-bullseye-2021-07-01@sha256:f1e25694fe933c7970773cb323975bb5c995fa91d0c1a148f4f1c131cbc5872c
ARG           FROM_IMAGE_NODE=base:node-bullseye-2021-07-01@sha256:d201555186aa4982ba6aa48fb283d2ce5e74e50379a7b9e960c22a10ee23ba54

FROM          $FROM_REGISTRY/$FROM_IMAGE_NODE                                                                           AS node

FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_BUILDER                                              AS fetcher-main

ENV           GIT_REPO=github.com/elastic/kibana
ENV           GIT_VERSION=v7.13.4
ENV           GIT_COMMIT=024b8904d1508252df7cb41ac98f48c48f7bcb33

RUN           git clone --recurse-submodules git://"$GIT_REPO" .
RUN           git checkout "$GIT_COMMIT"

#######################
# Main builder
#######################
FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_BUILDER                                              AS builder-main

ARG           TARGETPLATFORM

ARG           VERSION=7.13.4
ARG           AMD64_SHA512=1accd5d6933f3f2f54174e53da626bc275b99b2f102d5f8cfee934d3520ee55a97c9c545cca32ddffec06a96114ce284e2e128cf334538214566c6530d1d673e
ARG           ARM64_SHA512=8bead967f8045596a31b12027c76319dccad37ec35bfc775a6543a7801330250c245679bab1e24a8d9f8d4b870e604c0de98ad5ba07f031f80e813fd0e771db3

WORKDIR       /dist/boot

RUN           --mount=type=secret,id=CA \
              --mount=type=secret,id=CERTIFICATE \
              --mount=type=secret,id=KEY \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=.curlrc \
              case "$TARGETPLATFORM" in \
                "linux/amd64")    arch=x86_64;      checksum=$AMD64_SHA512;      ;; \
                "linux/arm64")    arch=aarch64;     checksum=$ARM64_SHA512;     ;; \
              esac; \
              curl -sSfL -o archive.tgz https://artifacts.elastic.co/downloads/kibana/kibana-"${VERSION}"-linux-"$arch".tar.gz; \
              printf "Downloaded shasum: %s\n" "$(sha512sum archive.tgz)"; \
              printf "%s *archive.tgz" "$checksum" | sha512sum -c -; \
              tar --strip-components=1 -zxf archive.tgz; \
              rm archive.tgz; \
              rm config/kibana.yml; \
              ln -s /config/kibana/main.yml config/kibana.yml

FROM          --platform=$BUILDPLATFORM fetcher-main                                                                    AS builder-main-build

ARG           TARGETARCH
ARG           TARGETOS
ARG           TARGETVARIANT

COPY          --from=node /usr/local/bin/node /dist/boot/bin/node
COPY          --from=node /usr/local/bin/node /dist/boot/bin/nodejs
COPY          --from=node /usr/local/bin/yarn /dist/boot/bin/yarn
COPY          --from=node /usr/local/bin/yarn /dist/boot/bin/yarnpkg

ARG           npm_config_arch=$TARGETARCH
ARG           PATH=$PATH:/dist/boot/bin
RUN           yarn build --skip-os-packages

# Embark node as well from the builder image
RUN           ls -lA target; exit 1
RUN           rm config/kibana.yml; ln -s /config/kibana/main.yml config/kibana.yml

#######################
# Builder assembly, XXX should be auditor
#######################
FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_BUILDER                                              AS builder

COPY          --from=builder-main-build /dist/boot/bin           /dist/boot/bin

COPY          --from=builder-tools  /boot/bin/goello-server  /dist/boot/bin
COPY          --from=builder-tools  /boot/bin/caddy          /dist/boot/bin
COPY          --from=builder-tools  /boot/bin/http-health    /dist/boot/bin

RUN           chmod 555 /dist/boot/bin/*; \
              epoch="$(date --date "$BUILD_CREATED" +%s)"; \
              find /dist/boot -newermt "@$epoch" -exec touch --no-dereference --date="@$epoch" '{}' +;

#######################
# Running image
#######################
FROM          $FROM_REGISTRY/$FROM_IMAGE_RUNTIME

USER          root

RUN           --mount=type=secret,uid=100,id=CA \
              --mount=type=secret,uid=100,id=CERTIFICATE \
              --mount=type=secret,uid=100,id=KEY \
              --mount=type=secret,uid=100,id=GPG.gpg \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=APT_SOURCES \
              --mount=type=secret,id=APT_CONFIG \
              apt-get update -qq          && \
              apt-get install -qq --no-install-recommends \
                fontconfig=2.13.1-4.2 \
                libfreetype6=2.10.4+dfsg-1      && \
              apt-get -qq autoremove      && \
              apt-get -qq clean           && \
              rm -rf /var/lib/apt/lists/* && \
              rm -rf /tmp/*               && \
              rm -rf /var/tmp/*

# fonts-liberation=1:1.07.4-11 libfontconfig1=2.13.1-4.2

# xpack.monitoring.ui.container.elasticsearch.enabled: true

USER          dubo-dubon-duponey

ENV           ELASTICSEARCH_HOSTS="https://elastic.local:4443"
ENV           NICK="kibana"

COPY          --from=builder --chown=$BUILD_UID:root /dist /

### Front server configuration
# Port to use
ENV           PORT=4443
EXPOSE        4443
# Log verbosity for
ENV           LOG_LEVEL="warn"
# Domain name to serve
ENV           DOMAIN="$NICK.local"
# Control wether tls is going to be "internal" (eg: self-signed), or alternatively an email address to enable letsencrypt
ENV           TLS="internal"
# Either require_and_verify or verify_if_given
ENV           MTLS_MODE="verify_if_given"

# Realm in case access is authenticated
ENV           REALM="My Precious Realm"
# Provide username and password here (call the container with the "hash" command to generate a properly encrypted password, otherwise, a random one will be generated)
ENV           USERNAME=""
ENV           PASSWORD=""

### mDNS broadcasting
# Enable/disable mDNS support
ENV           MDNS_ENABLED=false
# Name is used as a short description for the service
ENV           MDNS_NAME="mDNS display name"
# The service will be annonced and reachable at $MDNS_HOST.local
ENV           MDNS_HOST="$NICK"
# Type to advertise
ENV           MDNS_TYPE="_http._tcp"

# Caddy certs will be stored here
VOLUME        /certs

# Caddy uses this
VOLUME        /tmp

# Used by the backend service
VOLUME        /data

ENV           HEALTHCHECK_URL="http://127.0.0.1:10000/?healthcheck"

HEALTHCHECK   --interval=120s --timeout=30s --start-period=10s --retries=1 CMD http-health || exit 1
