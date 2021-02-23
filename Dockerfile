ARG           BUILDER_BASE=dubodubonduponey/base@sha256:b51f084380bc1bd2b665840317b6f19ccc844ee2fc7e700bf8633d95deba2819
ARG           RUNTIME_BASE=dubodubonduponey/base@sha256:d28e8eed3e87e8dc5afdd56367d3cf2da12a0003d064b5c62405afbe4725ee99

#######################
# Extra builder for healthchecker
#######################
# hadolint ignore=DL3006,DL3029
FROM          --platform=$BUILDPLATFORM $BUILDER_BASE                                                                   AS builder-healthcheck

ARG           GIT_REPO=github.com/dubo-dubon-duponey/healthcheckers
ARG           GIT_VERSION=51ebf8ca3d255e0c846307bf72740f731e6210c3
ARG           BUILD_TARGET=./cmd/http
ARG           BUILD_OUTPUT=http-health
ARG           BUILD_FLAGS="-s -w"

WORKDIR       $GOPATH/src/$GIT_REPO
RUN           git clone git://$GIT_REPO .
RUN           git checkout $GIT_VERSION
# hadolint ignore=DL4006
RUN           env GOOS=linux GOARCH="$(printf "%s" "$TARGETPLATFORM" | sed -E 's/^[^/]+\/([^/]+).*/\1/')" go build -v \
                -ldflags "$BUILD_FLAGS" -o /dist/boot/bin/"$BUILD_OUTPUT" "$BUILD_TARGET"

#######################
# Goello
#######################
# hadolint ignore=DL3006,DL3029
FROM          --platform=$BUILDPLATFORM $BUILDER_BASE                                                                   AS builder-goello

ARG           GIT_REPO=github.com/dubo-dubon-duponey/goello
ARG           GIT_VERSION=3799b6035dd5c4d5d1c061259241a9bedda810d6
ARG           BUILD_TARGET=./cmd/server
ARG           BUILD_OUTPUT=goello-server
ARG           BUILD_FLAGS="-s -w"

WORKDIR       $GOPATH/src/$GIT_REPO
RUN           git clone git://$GIT_REPO .
RUN           git checkout $GIT_VERSION
# hadolint ignore=DL4006
RUN           env GOOS=linux GOARCH="$(printf "%s" "$TARGETPLATFORM" | sed -E 's/^[^/]+\/([^/]+).*/\1/')" go build -v \
                -ldflags "$BUILD_FLAGS" -o /dist/boot/bin/"$BUILD_OUTPUT" "$BUILD_TARGET"

#######################
# Caddy
#######################
# hadolint ignore=DL3006,DL3029
FROM          --platform=$BUILDPLATFORM $BUILDER_BASE                                                                   AS builder-caddy

# This is 2.3.0
ARG           GIT_REPO=github.com/caddyserver/caddy
ARG           GIT_VERSION=1b453dd4fbea2f3a54362fb4c2115bab85cad1b7
ARG           BUILD_TARGET=./cmd/caddy
ARG           BUILD_OUTPUT=caddy
ARG           BUILD_FLAGS="-s -w"

WORKDIR       $GOPATH/src/$GIT_REPO
RUN           git clone https://$GIT_REPO .
RUN           git checkout $GIT_VERSION
# hadolint ignore=DL4006
RUN           env GOOS=linux GOARCH="$(printf "%s" "$TARGETPLATFORM" | sed -E 's/^[^/]+\/([^/]+).*/\1/')" go build -v \
                -ldflags "$BUILD_FLAGS" -o /dist/boot/bin/"$BUILD_OUTPUT" "$BUILD_TARGET"

#######################
# Main builder
#######################
# hadolint ignore=DL3006,DL3029
FROM          --platform=$BUILDPLATFORM $BUILDER_BASE                                                                   AS builder-main

# Note that this is tied to x86_64 and not a proper multi-arch image
ARG           KBN_VERSION=7.11.1
ARG           KBN_AMD64_SHA512=5facaac7adced5ac2830158d6a7994d9c32e042c320f250626166a9e86cce3fa4c3e8b92809526492b4d09b0b8623ea2c3bfd02751a8f1387bc3f09a1bee642b
ARG           KBN_AARCH64_SHA512=af451e0aab7f3934c733240cd5f84513b54188357de81de9b03f085a84dfc18694af547c5c943632feb13dfce211b2f03bba488b6f475338cc6e15c7cd422c59

RUN           apt-get update -qq \
              && apt-get install -qq --no-install-recommends \
                curl=7.64.0-4+deb10u1

WORKDIR       /dist/boot

# hadolint ignore=DL4006
RUN           set -eu; \
              case "$TARGETPLATFORM" in \
                "linux/amd64")    arch=x86_64;      checksum=$KBN_AMD64_SHA512;      ;; \
                "linux/arm64")    arch=aarch64;     checksum=$KBN_AARCH64_SHA512;     ;; \
              esac; \
              curl --proto '=https' --tlsv1.2 -sSfL -o archive.tgz https://artifacts.elastic.co/downloads/kibana/kibana-"${KBN_VERSION}"-linux-"$arch".tar.gz; \
              printf "Downloaded shasum: %s\n" "$(sha512sum archive.tgz)"; \
              printf "%s *archive.tgz" "$checksum" | sha512sum -c -; \
              tar --strip-components=1 -zxf archive.tgz; \
              rm archive.tgz; \
              rm config/kibana.yml; \
              ln -s /config/kibana/main.yml config/kibana.yml
              # For now, revert to the provided node...
              # rm node/bin/node; \
              # ln -s /usr/bin/node node/bin/node;

#######################
# Builder assembly
#######################
# hadolint ignore=DL3006
FROM          $BUILDER_BASE                                                                                             AS builder

COPY          --from=builder-healthcheck /dist/boot/bin /dist/boot/bin
COPY          --from=builder-goello /dist/boot/bin /dist/boot/bin
COPY          --from=builder-caddy /dist/boot/bin /dist/boot/bin
COPY          --from=builder-main /dist/boot/bin /dist/boot/bin

RUN           chmod 555 /dist/boot/bin/*; \
              epoch="$(date --date "$BUILD_CREATED" +%s)"; \
              find /dist/boot/bin -newermt "@$epoch" -exec touch --no-dereference --date="@$epoch" '{}' +;

#######################
# Running image
#######################
# hadolint ignore=DL3006
FROM          $RUNTIME_BASE

USER          root

# Using the bundled node for now
# nodejs=10.21.0~dfsg-1~deb10u1 \
RUN           apt-get update -qq          && \
              apt-get install -qq --no-install-recommends \
                fontconfig=2.13.1-2 \
                libfreetype6=2.9.1-3+deb10u1      && \
              apt-get -qq autoremove      && \
              apt-get -qq clean           && \
              rm -rf /var/lib/apt/lists/* && \
              rm -rf /tmp/*               && \
              rm -rf /var/tmp/*

USER          dubo-dubon-duponey

#ENV           NODE_VERSION=14.15.4
#ENV           YARN_VERSION=1.22.5

#RUN           curl --proto '=https' --tlsv1.2 -sSfL -o node.tar.gz "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.gz"

#ADD           ./cache/$TARGETPLATFORM/node-$NODE_VERSION.tar.gz /opt
#ADD           ./cache/$TARGETPLATFORM/yarn-$YARN_VERSION.tar.gz /opt

#RUN           set -eu; \
#              ln -s /opt/node-*/bin/* /usr/local/bin/; \
#              ln -s /usr/local/bin/node /usr/local/bin/nodejs

#              ln -s /opt/yarn-*/bin/yarn /usr/local/bin/; \
#              ln -s /opt/yarn-*/bin/yarnpkg /usr/local/bin/; \

# Bring in Kibana from the initial stage.
COPY          --from=builder --chown=$BUILD_UID:root /dist .
COPY          --from=builder-main /dist/boot /boot

### Front server configuration
# Port to use
ENV           PORT=4443
EXPOSE        4443
# Log verbosity for
ENV           LOG_LEVEL=info
# Domain name to serve
ENV           DOMAIN="kibana.local"
# Control wether tls is going to be "internal" (eg: self-signed), or alternatively an email address to enable letsencrypt
ENV           TLS="internal"

# Salt and realm in case anything is authenticated
ENV           SALT="eW91IGFyZSBzbyBzbWFydAo="
ENV           REALM="My precious"
# if authenticated, pass along a username and bcrypted password (call the container with the "hash" command to generate one)
ENV           USERNAME=""
ENV           PASSWORD=""

### mDNS broadcasting
# Enable/disable mDNS support
ENV           MDNS_ENABLED=false
# Name is used as a short description for the service
ENV           MDNS_NAME="Fancy Service Name"
# The service will be annonced and reachable at $MDNS_HOST.local
ENV           MDNS_HOST=kibana
# Type being advertised
ENV           MDNS_TYPE=_http._tcp

# Caddy certs will be stored here
VOLUME        /certs

# Caddy uses this
VOLUME        /tmp

# Kibana configuration defaults
ENV           ELASTIC_CONTAINER=true

ENV           ELASTICSEARCH_HOSTS="http://elasticsearch:9200"

# Default volumes for data
VOLUME        /data

# From 7.5, it seems now this is needed for /tmp/chromium-XXXXXX
VOLUME        /tmp
# XXX eff you kbn
VOLUME        /boot/optimize

# xpack.monitoring.ui.container.elasticsearch.enabled: true
# XXX this won't work as kibana apparently no longer binds on localhost
ENV           HEALTHCHECK_URL="http://127.0.0.1:10042/api/status?healthcheck"
# TODO make interval configurable
HEALTHCHECK   --interval=30s --timeout=30s --start-period=10s --retries=1 CMD http-health || exit 1
