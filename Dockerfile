#######################
# Extra builder for healthchecker
#######################
FROM          --platform=$BUILDPLATFORM dubodubonduponey/base:builder                                                   AS builder-healthcheck

ARG           HEALTH_VER=51ebf8ca3d255e0c846307bf72740f731e6210c3

WORKDIR       $GOPATH/src/github.com/dubo-dubon-duponey/healthcheckers
RUN           git clone git://github.com/dubo-dubon-duponey/healthcheckers .
RUN           git checkout $HEALTH_VER
RUN           arch="${TARGETPLATFORM#*/}"; \
              env GOOS=linux GOARCH="${arch%/*}" go build -v -ldflags "-s -w" -o /dist/bin/http-health ./cmd/http

RUN           chmod 555 /dist/bin/*

#######################
# Building image
#######################
FROM          dubodubonduponey/base:builder                                                                             AS builder

ENV           KBN_VERSION=7.4.0
ENV           KBN_AMD64_SHA512=6c0fe42299a868b9091da9e8326b4242f843a68b9f5e032a1e82b87e6eb861529be23a737dfc8ffbe0a7a7469dd600847a8b247f7c1d5da0fe342079e9733af5

WORKDIR       /build/kibana

# hadolint ignore=DL4006
RUN           set -eu; \
              checksum=$KBN_AMD64_SHA512; \
              curl -k -fsSL -o kbn.tgz "https://artifacts.elastic.co/downloads/kibana/kibana-${KBN_VERSION}-linux-x86_64.tar.gz"; \
              printf "%s *kbn.tgz" "$checksum" | sha512sum -c -; \
              tar --strip-components=1 -zxf kbn.tgz; \
              rm kbn.tgz; \
              rm node/bin/node; \
              rm config/kibana.yml; \
              ln -s /usr/bin/node node/bin/node; \
              ln -s /config/kibana.yml config/kibana.yml

#######################
# Running image
#######################
FROM          dubodubonduponey/base:runtime

USER          root

RUN           apt-get update -qq          && \
              apt-get install -qq --no-install-recommends \
                nodejs=10.15.2~dfsg-2 \
                fontconfig=2.13.1-2 \
                libfreetype6=2.9.1-3      && \
              apt-get -qq autoremove      && \
              apt-get -qq clean           && \
              rm -rf /var/lib/apt/lists/* && \
              rm -rf /tmp/*               && \
              rm -rf /var/tmp/*

USER          dubo-dubon-duponey

# Bring in Kibana from the initial stage.
COPY          --from=builder --chown=$BUILD_UID:root /build/kibana /boot
COPY          --from=builder-healthcheck  /dist/bin/http-health ./bin/

# Set some Kibana configuration defaults.
ENV           ELASTIC_CONTAINER true

ENV           SERVER_NAME kibana
ENV           SERVER_HOST kibana
ENV           ELASTICSEARCH_HOSTS "http://elasticsearch:9200"
# xpack.monitoring.ui.container.elasticsearch.enabled: true
ENV           HEALTHCHECK_URL="http://127.0.0.1:5601"

VOLUME        /data
# XXX eff you kbn
VOLUME        /boot/optimize

# Default volumes for data and certs, since these are expected to be writable
EXPOSE        5601

HEALTHCHECK --interval=30s --timeout=30s --start-period=10s --retries=1 CMD http-health || exit 1



