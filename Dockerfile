ARG           FROM_REGISTRY=ghcr.io/dubo-dubon-duponey

ARG           FROM_IMAGE_BUILDER=base:builder-bullseye-2021-09-01@sha256:12be2a6d0a64b59b1fc44f9b420761ad92efe8188177171163b15148b312481a
ARG           FROM_IMAGE_AUDITOR=base:auditor-bullseye-2021-09-01@sha256:28d5eddcbbee12bc671733793c8ea8302d7d79eb8ab9ba0581deeacabd307cf5
ARG           FROM_IMAGE_RUNTIME=base:runtime-bullseye-2021-09-01@sha256:bbd3439247ea1aa91b048e77c8b546369138f910b5083de697f0d36ac21c1a8c
ARG           FROM_IMAGE_TOOLS=tools:linux-bullseye-2021-09-01@sha256:e5535efb771ca60d2a371cd2ca2eb1a7d6b7b13cc5c4d27d48613df1a041431d
ARG           FROM_IMAGE_NODE=base:node-bullseye-2021-09-01@sha256:e9429c1d809c6a6bd10f1b4a6bdd5b2465e17b6c6b8588e59d8c51a2f536c6c3

FROM          $FROM_REGISTRY/$FROM_IMAGE_TOOLS                                                                          AS builder-tools
FROM          $FROM_REGISTRY/$FROM_IMAGE_NODE                                                                           AS node

FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_BUILDER                                              AS fetcher-main

ARG           GIT_REPO=github.com/elastic/kibana
ARG           GIT_VERSION=v7.14.0
ARG           GIT_COMMIT=f032cf9bdbf6f74b70db5e43b7b1d30f5de22d3e

RUN           git clone --recurse-submodules git://"$GIT_REPO" .; git checkout "$GIT_COMMIT"

#######################
# Main builder
#######################
FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_BUILDER                                              AS builder-main

ARG           TARGETPLATFORM

ARG           VERSION=7.14.0
ARG           AMD64_SHA512=0ca36be3345bb2cec0739274d8f57b84775ec8f545d26cfc0556b1014c4bc99e0c015d85aa09f0ad105e2181fb2bad449819f6386caad2f2d9402383c5644473
ARG           ARM64_SHA512=3936653aca2e21d3fe19c2bff79fa2600606fb6684d5220e2e2e019d964d8ca66e839be6ebf24f17def1c431f0130e0aa7babbd9ccddedabfa144a36595bd23a

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


FROM          --platform=$BUILDPLATFORM node                                                                            AS builder-main-build

ARG           TARGETARCH
ARG           TARGETOS
ARG           TARGETVARIANT

COPY          --from=fetcher-main /source .

RUN           --mount=type=secret,uid=100,id=CA \
              --mount=type=secret,uid=100,id=CERTIFICATE \
              --mount=type=secret,uid=100,id=KEY \
              --mount=type=secret,uid=100,id=GPG.gpg \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=APT_SOURCES \
              --mount=type=secret,id=APT_CONFIG \
              apt-get update -qq; apt-get install libatomic1 python --no-install-recommends -qq

ARG           npm_config_arch=$TARGETARCH
# Remove node engine moronic version restriction
RUN           sed -Ei 's/  "node": "14[.].+",//g' package.json

RUN           yarn install --production=false
RUN           yarn build --skip-os-packages

RUN           rm config/kibana.yml; ln -s /config/kibana/main.yml config/kibana.yml

RUN           eval "$(dpkg-architecture -A "$(echo "$TARGETARCH$TARGETVARIANT" | sed -e "s/^armv6$/armel/" -e "s/^armv7$/armhf/" -e "s/^ppc64le$/ppc64el/" -e "s/^386$/i386/")")"; \
              mkdir -p /dist/boot/lib; \
              cp /usr/lib/"$DEB_TARGET_MULTIARCH"/libstdc++.so.6   /dist/boot/lib; \
              mv /opt/* /dist/boot; \
              mv /usr/local/bin/node /dist/boot/bin/node; \
              mv /usr/local/bin/nodejs /dist/boot/bin/nodejs; \
              mv /usr/local/bin/yarn /dist/boot/bin/yarn; \
              mv /usr/local/bin/yarnpkg /dist/boot/bin/yarnpkg

#              cp /usr/lib/"$DEB_TARGET_MULTIARCH"/libatomic.so.1   /dist/boot/lib; \

FROM          --platform=$BUILDPLATFORM fetcher-main                                                                    AS builder-main-build_xxx

ARG           TARGETARCH
ARG           TARGETOS
ARG           TARGETVARIANT

COPY          --from=node /usr/local/bin/node /dist/boot/bin/node
COPY          --from=node /usr/local/bin/node /dist/boot/bin/nodejs
COPY          --from=node /usr/local/bin/yarn /dist/boot/bin/yarn
COPY          --from=node /usr/local/bin/yarn /dist/boot/bin/yarnpkg
COPY          --from=node /opt /opt
COPY          --from=node /opt /dist/opt

# Getting worse by the minute
COPY          --from=node "/usr/lib" "/tmp/usr/lib"

RUN           eval "$(dpkg-architecture -A "$(echo "$TARGETARCH$TARGETVARIANT" | sed -e "s/^armv6$/armel/" -e "s/^armv7$/armhf/" -e "s/^ppc64le$/ppc64el/" -e "s/^386$/i386/")")"; \
              mkdir -p /dist/boot/lib; \
              cp /tmp/usr/lib/"$DEB_TARGET_MULTIARCH"/libstdc++.so.6   /dist/boot/lib; \
              cp /tmp/usr/lib/"$DEB_TARGET_MULTIARCH"/libstdc++.so.6   /usr/lib/"$DEB_TARGET_MULTIARCH"/libstdc++.so.6

#COPY          --from=node "/usr/lib/x86_64-linux-gnu/libstdc++.so.6" "/usr/lib/x86_64-linux-gnu/libstdc++.so.6"
#COPY          --from=node "/usr/lib/x86_64-linux-gnu/libstdc++.so.6" /dist/boot/lib

ARG           npm_config_arch=$TARGETARCH
ARG           PATH=$PATH:/dist/boot/bin
RUN           sed -Ei 's/  "node": "14[.].+",//g' package.json
RUN           yarn install --production=false
RUN           cat package.json; yarn build --skip-os-packages

# Embark node as well from the builder image
#RUN           ls -lA target; exit 1
RUN           rm config/kibana.yml; ln -s /config/kibana/main.yml config/kibana.yml

#######################
# Builder assembly, XXX should be auditor
#######################
FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_AUDITOR                                              AS builder

COPY          --from=builder-main   /dist/boot/bin           /dist/boot/bin

COPY          --from=builder-tools  /boot/bin/goello-server  /dist/boot/bin
COPY          --from=builder-tools  /boot/bin/caddy          /dist/boot/bin
COPY          --from=builder-tools  /boot/bin/http-health    /dist/boot/bin

RUN           setcap 'cap_net_bind_service+ep' /dist/boot/bin/caddy

# RUN           patchelf --set-rpath '$ORIGIN/../lib'           /dist/boot/lib/*
# RUN           patchelf --set-rpath '$ORIGIN/../lib'           /dist/boot/bin/caddy

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
ENV           PORT_HTTP=80
EXPOSE        4443
EXPOSE        80
# Log verbosity for
ENV           LOG_LEVEL="warn"
# Domain name to serve
ENV           DOMAIN="$NICK.local"
ENV           ADDITIONAL_DOMAINS=""

# Whether the server should behave as a proxy (disallows mTLS)
ENV           SERVER_NAME="DuboDubonDuponey/1.0 (Caddy/2) [$NICK]"

# Control wether tls is going to be "internal" (eg: self-signed), or alternatively an email address to enable letsencrypt
ENV           TLS="internal"
# 1.2 or 1.3
ENV           TLS_MIN=1.2
# Either require_and_verify or verify_if_given
ENV           TLS_MTLS_MODE="verify_if_given"
# Issuer name to appear in certificates
#ENV           TLS_ISSUER="Dubo Dubon Duponey"
# Either disable_redirects or ignore_loaded_certs if one wants the redirects
ENV           TLS_AUTO=disable_redirects

ENV           AUTH_ENABLED=false
# Realm in case access is authenticated
ENV           AUTH_REALM="My Precious Realm"
# Provide username and password here (call the container with the "hash" command to generate a properly encrypted password, otherwise, a random one will be generated)
ENV           AUTH_USERNAME="dubo-dubon-duponey"
ENV           AUTH_PASSWORD="cmVwbGFjZV9tZV93aXRoX3NvbWV0aGluZwo="

### mDNS broadcasting
# Enable/disable mDNS support
ENV           MDNS_ENABLED=false
# Name is used as a short description for the service
ENV           MDNS_NAME="$NICK mDNS display name"
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
