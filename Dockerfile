ARG           BUILDER_BASE=dubodubonduponey/base:builder
ARG           RUNTIME_BASE=dubodubonduponey/base:runtime

#######################
# Extra builder for healthchecker
#######################
# hadolint ignore=DL3006
FROM          --platform=$BUILDPLATFORM $BUILDER_BASE                                                                   AS builder-healthcheck

ARG           GIT_REPO=github.com/dubo-dubon-duponey/healthcheckers
ARG           GIT_VERSION=51ebf8ca3d255e0c846307bf72740f731e6210c3

WORKDIR       $GOPATH/src/$GIT_REPO
RUN           git clone git://$GIT_REPO .
RUN           git checkout $GIT_VERSION
RUN           arch="${TARGETPLATFORM#*/}"; \
              env GOOS=linux GOARCH="${arch%/*}" go build -v -ldflags "-s -w" \
                -o /dist/boot/bin/http-health ./cmd/http

#######################
# Building image
#######################
# hadolint ignore=DL3006
FROM          $BUILDER_BASE                                                                                             AS builder

# ENV           KBN_VERSION=7.5.0
#ENV           KBN_AMD64_SHA512=7c99c54bd8d34b707e788702e5a1a570e9504822af77d7b7d0ab3e80048be673c342953551508afc93c2b58aa78ec3cc68939b893601a94bd4ccaa206c9804bb
#ENV           KBN_VERSION=7.5.2
#ENV           KBN_AMD64_SHA512=7717eabe15a2ccd50cdc2acce592fc60af303516af2337145ab59be901d781e6545503a969ff7147e71e7189404ecbc870898daa92292e42002390f65e7cae41
ENV           KBN_VERSION=7.7.1
ENV           KBN_AMD64_SHA512=d3bc9257e04cfe1691756b29793ba7fb1affa742e70689045c0d023edf5db7968e3bdb874976c78ae19446cd2de12179adead059c7fc8b134405e3de0305b8f5

RUN           apt-get update -qq \
              && apt-get install -qq --no-install-recommends \
                curl=7.64.0-4+deb10u1

WORKDIR       /dist/boot

# hadolint ignore=DL4006
RUN           set -eu; \
              checksum=$KBN_AMD64_SHA512; \
              curl -k -fsSL -o archive.tgz https://artifacts.elastic.co/downloads/kibana/kibana-"${KBN_VERSION}"-linux-x86_64.tar.gz; \
              printf "Downloaded shasum: %s\n" "$(sha512sum archive.tgz)"; \
              printf "%s *archive.tgz" "$checksum" | sha512sum -c -; \
              tar --strip-components=1 -zxf archive.tgz; \
              rm archive.tgz; \
              rm node/bin/node; \
              rm config/kibana.yml; \
              ln -s /usr/bin/node node/bin/node; \
              ln -s /config/kibana.yml config/kibana.yml

COPY          --from=builder-healthcheck /dist/boot/bin           /dist/boot/bin
RUN           chmod 555 /dist/boot/bin/*

#######################
# Running image
#######################
# hadolint ignore=DL3006
FROM          $RUNTIME_BASE

USER          root

RUN           apt-get update -qq          && \
              apt-get install -qq --no-install-recommends \
                nodejs=10.19.0~dfsg1-1 \
                fontconfig=2.13.1-2 \
                libfreetype6=2.9.1-3+deb10u1      && \
              apt-get -qq autoremove      && \
              apt-get -qq clean           && \
              rm -rf /var/lib/apt/lists/* && \
              rm -rf /tmp/*               && \
              rm -rf /var/tmp/*

USER          dubo-dubon-duponey

# Bring in Kibana from the initial stage.
COPY          --from=builder --chown=$BUILD_UID:root /dist .

# Set some Kibana configuration defaults.
ENV           ELASTIC_CONTAINER true

ENV           SERVER_NAME kibana
ENV           SERVER_HOST kibana
ENV           ELASTICSEARCH_HOSTS "http://elasticsearch:9200"
# xpack.monitoring.ui.container.elasticsearch.enabled: true
# XXX this won't work as kibana apparently no longer binds on localhost
ENV           HEALTHCHECK_URL="http://127.0.0.1:5601/api/status?healthcheck"

# Default volumes for data
VOLUME        /data

# From 7.5, it seems now this is needed for /tmp/chromium-XXXXXX
VOLUME        /tmp
# XXX eff you kbn
VOLUME        /boot/optimize

EXPOSE        5601

HEALTHCHECK --interval=30s --timeout=30s --start-period=10s --retries=1 CMD http-health || exit 1



