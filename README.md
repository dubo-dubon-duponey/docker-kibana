# What

Docker image for Kibana.

This is based on [Kibana](https://github.com/elastic/kibana).

## Image features

* multi-architecture:
  * [x] linux/amd64
  * [x] linux/386
  * [x] linux/arm64
  * [x] linux/arm/v7
  * [x] linux/arm/v6
  * [x] linux/ppc64le
  * [x] linux/s390x
* hardened:
  * [x] image runs read-only
  * [x] image runs with no capabilities but NET_BIND_SERVICE
  * [x] process runs as a non-root user, disabled login, no shell
* lightweight
  * [x] based on our slim [Debian Bullseye](https://github.com/dubo-dubon-duponey/docker-debian)
  * [x] simple entrypoint script
  * [x] multi-stage build with no installed dependencies for the runtime image
* observable
  * [x] healthcheck
  * [x] log to stdout
  * [ ] ~~prometheus endpoint~~

    * [ ] ~~linux/arm/v7~~ unsupported by Kibana
    * [ ] ~~linux/arm/v6~~ unsupported by Kibana

    * [ ] multi-stage build with ~~no installed~~ dependencies for the runtime image:
        * fontconfig
        * libfreetype6

## Run

See [example script](example/example.sh) for a complete stack including Elastic.

For Kibana specifically:

```bash

# Domain name for your Elastic server (will be used to generate self-signed certificates, and also as a container name)
ES_DOMAIN=myelastic.local
# Same, for kibana
KBN_DOMAIN=mykibana.local
# Port used for Elastic
ES_PORT=5000
# Port to expose for Kibana
KBN_PORT=5001

# Username and password (same for Elastic & Kibana for simplicity, but you may (should!) use different credentials for both services)
USERNAME=my_elastic_username
PASSWORD=secret_password

######################################
# Password salting
######################################

# Generate the salted password hash
SALTED_PASSWORD="$(docker run --rm ghcr.io/dubo-dubon-duponey/elastic hash -plaintext "$PASSWORD" 2>/dev/null)"
# If you prefer *not* to pass the plaintext password, you can provide it interactively and manually copy the output into SALTED_PASSWORD
# docker run -ti ghcr.io/dubo-dubon-duponey/elastic hash-interactive

mkdir -p certificates

docker network create dubo-bridge 2>/dev/null || true

######################################
# Kibana
######################################
docker rm -f "$KBN_DOMAIN" 2>/dev/null || true

# --cap-drop ALL --read-only \
docker run -d \
  -v $(pwd)/certificates:/certs \
  --user $(id -u) \
  --net dubo-bridge \
  --name "$KBN_DOMAIN" \
  --publish "$KBN_PORT:$KBN_PORT" \
  --env DOMAIN="$KBN_DOMAIN" \
  --env PORT="$KBN_PORT" \
  --env USERNAME="$USERNAME" \
  --env PASSWORD="$SALTED_PASSWORD" \
  --env ELASTICSEARCH_HOSTS="https://$ES_DOMAIN:$ES_PORT" \
  --env ELASTICSEARCH_SSL_CERTIFICATEAUTHORITIES=/certs/pki/authorities/local/root.crt \
  --env ELASTICSEARCH_USERNAME="$USERNAME" \
  --env ELASTICSEARCH_PASSWORD="$PASSWORD" \
  ghcr.io/dubo-dubon-duponey/kibana
```

## Notes

### Prometheus

Not applicable.

## Moar?

See [DEVELOP.md](DEVELOP.md)
