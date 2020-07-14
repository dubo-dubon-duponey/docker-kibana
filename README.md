# What

Docker image for Kibana.

This is based on [Kibana](https://github.com/elastic/kibana).

## Image features

 * multi-architecture:
    * [x] linux/amd64
    * [ ] ~~linux/arm64~~ unsupported by Kibana
    * [ ] ~~linux/arm/v7~~ unsupported by Kibana
    * [ ] ~~linux/arm/v6~~ unsupported by Kibana
 * hardened:
    * [x] image runs read-only
    * [x] image runs with no capabilities
    * [x] process runs as a non-root user, disabled login, no shell
 * lightweight
    * [x] based on our slim [Debian buster version](https://github.com/dubo-dubon-duponey/docker-debian)
    * [x] simple entrypoint script
    * [ ] multi-stage build with ~~no installed~~ dependencies for the runtime image:
        * nodejs
        * fontconfig
        * libfreetype6
 * observable
    * [x] healthcheck
    * [x] log to stdout
    * [ ] ~~prometheus endpoint~~ not applicable

## Run

```bash
docker run -d \
    --net bridge \
    --cap-drop ALL \
    --read-only \
    dubodubonduponey/kibana
```

## Notes

### Prometheus

Not applicable.

## Moar?

See [DEVELOP.md](DEVELOP.md)
