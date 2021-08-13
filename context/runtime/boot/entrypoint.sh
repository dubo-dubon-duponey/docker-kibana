#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

[ -w /certs ] || {
  printf >&2 "/certs is not writable. Check your mount permissions.\n"
  exit 1
}

[ -w /tmp ] || {
  printf >&2 "/tmp is not writable. Check your mount permissions.\n"
  exit 1
}

[ -w /data ] || {
  printf >&2 "/data is not writable. Check your mount permissions.\n"
  exit 1
}

# Helpers
case "${1:-run}" in
  # Short hand helper to generate password hash
  "hash")
    shift
    printf >&2 "Generating password hash\n"
    caddy hash-password -algorithm bcrypt "$@"
    exit
  ;;
  # Helper to get the ca.crt out (once initialized)
  "cert")
    if [ "${TLS:-}" == "" ]; then
      printf >&2 "Your container is not configured for TLS termination - there is no local CA in that case."
      exit 1
    fi
    if [ "${TLS:-}" != "internal" ]; then
      printf >&2 "Your container uses letsencrypt - there is no local CA in that case."
      exit 1
    fi
    if [ ! -e /certs/pki/authorities/local/root.crt ]; then
      printf >&2 "No root certificate installed or generated. Run the container so that a cert is generated, or provide one at runtime."
      exit 1
    fi
    cat /certs/pki/authorities/local/root.crt
    exit
  ;;
  "run")
    # Bonjour the container if asked to. While the PORT is no guaranteed to be mapped on the host in bridge, this does not matter since mDNS will not work at all in bridge mode.
    if [ "${MDNS_ENABLED:-}" == true ]; then
      goello-server -json "$(printf '[{"Type": "%s", "Name": "%s", "Host": "%s", "Port": %s, "Text": {}}]' "$MDNS_TYPE" "$MDNS_NAME" "$MDNS_HOST" "$PORT")" &
    fi

    # If we want TLS and authentication, start caddy in the background
    if [ "${TLS:-}" ]; then
      HOME=/tmp/caddy-home caddy run -config /config/caddy/main.conf --adapter caddyfile &
    fi
  ;;
esac

# This is in the official dockerfile, so...
export ELASTIC_CONTAINER=true

# export LOGGING_DEST=/dev/stdout
# export PID_FILE=/tmp/kibana.pid
export PATH_DATA=/data/kibana

rm -f /tmp/kibana.pid

kibana_vars=(
    console.enabled
    console.proxyConfig
    console.proxyFilter
    ops.cGroupOverrides.cpuPath
    ops.cGroupOverrides.cpuAcctPath
    cpu.cgroup.path.override
    cpuacct.cgroup.path.override
    csp.rules
    csp.strict
    csp.warnLegacyBrowsers
    elasticsearch.customHeaders
    elasticsearch.hosts
    elasticsearch.logQueries
    elasticsearch.password
    elasticsearch.pingTimeout
    elasticsearch.requestHeadersWhitelist
    elasticsearch.requestTimeout
    elasticsearch.shardTimeout
    elasticsearch.sniffInterval
    elasticsearch.sniffOnConnectionFault
    elasticsearch.sniffOnStart
    elasticsearch.ssl.alwaysPresentCertificate
    elasticsearch.ssl.certificate
    elasticsearch.ssl.certificateAuthorities
    elasticsearch.ssl.key
    elasticsearch.ssl.keyPassphrase
    elasticsearch.ssl.keystore.path
    elasticsearch.ssl.keystore.password
    elasticsearch.ssl.truststore.path
    elasticsearch.ssl.truststore.password
    elasticsearch.ssl.verificationMode
    elasticsearch.username
    enterpriseSearch.accessCheckTimeout
    enterpriseSearch.accessCheckTimeoutWarning
    enterpriseSearch.enabled
    enterpriseSearch.host
    i18n.locale
    interpreter.enableInVisualize
    kibana.autocompleteTerminateAfter
    kibana.autocompleteTimeout
    kibana.defaultAppId
    kibana.index
    logging.dest
    logging.json
    logging.quiet
    logging.rotate.enabled
    logging.rotate.everyBytes
    logging.rotate.keepFiles
    logging.rotate.pollingInterval
    logging.rotate.usePolling
    logging.silent
    logging.useUTC
    logging.verbose
    map.includeElasticMapsService
    map.proxyElasticMapsServiceInMaps
    map.regionmap
    map.tilemap.options.attribution
    map.tilemap.options.maxZoom
    map.tilemap.options.minZoom
    map.tilemap.options.subdomains
    map.tilemap.url
    monitoring.cluster_alerts.email_notifications.email_address
    monitoring.enabled
    monitoring.kibana.collection.enabled
    monitoring.kibana.collection.interval
    monitoring.ui.container.elasticsearch.enabled
    monitoring.ui.container.logstash.enabled
    monitoring.ui.elasticsearch.password
    monitoring.ui.elasticsearch.pingTimeout
    monitoring.ui.elasticsearch.hosts
    monitoring.ui.elasticsearch.username
    monitoring.ui.elasticsearch.logFetchCount
    monitoring.ui.elasticsearch.ssl.certificateAuthorities
    monitoring.ui.elasticsearch.ssl.verificationMode
    monitoring.ui.enabled
    monitoring.ui.max_bucket_size
    monitoring.ui.min_interval_seconds
    newsfeed.enabled
    ops.interval
    path.data
    pid.file
    regionmap
    security.showInsecureClusterWarning
    server.basePath
    server.customResponseHeaders
    server.compression.enabled
    server.compression.referrerWhitelist
    server.cors
    server.cors.origin
    server.defaultRoute
    server.host
    server.keepAliveTimeout
    server.maxPayloadBytes
    server.name
    server.port
    server.rewriteBasePath
    server.socketTimeout
    server.ssl.cert
    server.ssl.certificate
    server.ssl.certificateAuthorities
    server.ssl.cipherSuites
    server.ssl.clientAuthentication
    server.customResponseHeaders
    server.ssl.enabled
    server.ssl.key
    server.ssl.keyPassphrase
    server.ssl.keystore.path
    server.ssl.keystore.password
    server.ssl.truststore.path
    server.ssl.truststore.password
    server.ssl.redirectHttpFromPort
    server.ssl.supportedProtocols
    server.xsrf.disableProtection
    server.xsrf.whitelist
    status.allowAnonymous
    status.v6ApiFormat
    tilemap.options.attribution
    tilemap.options.maxZoom
    tilemap.options.minZoom
    tilemap.options.subdomains
    tilemap.url
    timelion.enabled
    vega.enableExternalUrls
    xpack.actions.proxyUrl
    xpack.apm.enabled
    xpack.apm.serviceMapEnabled
    xpack.apm.ui.enabled
    xpack.apm.ui.maxTraceItems
    xpack.apm.ui.transactionGroupBucketSize
    apm_oss.apmAgentConfigurationIndex
    apm_oss.indexPattern
    apm_oss.errorIndices
    apm_oss.onboardingIndices
    apm_oss.spanIndices
    apm_oss.sourcemapIndices
    apm_oss.transactionIndices
    apm_oss.metricsIndices
    xpack.canvas.enabled
    xpack.code.ui.enabled
    xpack.code.disk.thresholdEnabled
    xpack.code.disk.watermarkLow
    xpack.code.maxWorkspace
    xpack.code.indexRepoFrequencyMs
    xpack.code.updateRepoFrequencyMs
    xpack.code.lsp.verbose
    xpack.code.verbose
    xpack.code.security.enableGitCertCheck
    xpack.code.security.gitHostWhitelist
    xpack.code.security.gitProtocolWhitelist
    xpack.encryptedSavedObjects.encryptionKey
    xpack.encryptedSavedObjects.keyRotation.decryptionOnlyKeys
    xpack.fleet.agents.elasticsearch.host
    xpack.fleet.agents.kibana.host
    xpack.fleet.agents.tlsCheckDisabled
    xpack.graph.enabled
    xpack.graph.canEditDrillDownUrls
    xpack.graph.savePolicy
    xpack.grokdebugger.enabled
    xpack.infra.enabled
    xpack.infra.query.partitionFactor
    xpack.infra.query.partitionSize
    xpack.infra.sources.default.fields.container
    xpack.infra.sources.default.fields.host
    xpack.infra.sources.default.fields.message
    xpack.infra.sources.default.fields.pod
    xpack.infra.sources.default.fields.tiebreaker
    xpack.infra.sources.default.fields.timestamp
    xpack.infra.sources.default.logAlias
    xpack.infra.sources.default.metricAlias
    xpack.ingestManager.fleet.tlsCheckDisabled
    xpack.ingestManager.registryUrl
    xpack.license_management.enabled
    xpack.maps.enabled
    xpack.maps.showMapVisualizationTypes
    xpack.ml.enabled
    xpack.reporting.capture.browser.autoDownload
    xpack.reporting.capture.browser.chromium.disableSandbox
    xpack.reporting.capture.browser.chromium.inspect
    xpack.reporting.capture.browser.chromium.maxScreenshotDimension
    xpack.reporting.capture.browser.chromium.proxy.enabled
    xpack.reporting.capture.browser.chromium.proxy.server
    xpack.reporting.capture.browser.chromium.proxy.bypass
    xpack.reporting.capture.browser.type
    xpack.reporting.capture.concurrency
    xpack.reporting.capture.loadDelay
    xpack.reporting.capture.settleTime
    xpack.reporting.capture.timeout
    xpack.reporting.capture.viewport.height
    xpack.reporting.capture.viewport.width
    xpack.reporting.capture.zoom
    xpack.reporting.csv.checkForFormulas
    xpack.reporting.csv.escapeFormulaValues
    xpack.reporting.csv.enablePanelActionDownload
    xpack.reporting.csv.useByteOrderMarkEncoding
    xpack.reporting.csv.maxSizeBytes
    xpack.reporting.csv.scroll.duration
    xpack.reporting.csv.scroll.size
    xpack.reporting.capture.maxAttempts
    xpack.reporting.capture.timeouts.openUrl
    xpack.reporting.capture.timeouts.waitForElements
    xpack.reporting.capture.timeouts.renderComplete
    xpack.reporting.enabled
    xpack.reporting.encryptionKey
    xpack.reporting.index
    xpack.reporting.kibanaApp
    xpack.reporting.kibanaServer.hostname
    xpack.reporting.kibanaServer.port
    xpack.reporting.kibanaServer.protocol
    xpack.reporting.poll.jobCompletionNotifier.interval
    xpack.reporting.poll.jobCompletionNotifier.intervalErrorMultiplier
    xpack.reporting.poll.jobsRefresh.interval
    xpack.reporting.poll.jobsRefresh.intervalErrorMultiplier
    xpack.reporting.queue.indexInterval
    xpack.reporting.queue.pollEnabled
    xpack.reporting.queue.pollInterval
    xpack.reporting.queue.pollIntervalErrorMultiplier
    xpack.reporting.queue.timeout
    xpack.reporting.roles.allow
    xpack.rollup.enabled
    xpack.security.audit.enabled
    xpack.searchprofiler.enabled
    xpack.security.authProviders
    xpack.security.authc.providers
    xpack.security.authc.oidc.realm
    xpack.security.authc.saml.realm
    xpack.security.authc.saml.maxRedirectURLSize
    xpack.security.authc.selector.enabled
    xpack.security.cookieName
    xpack.security.enabled
    xpack.security.encryptionKey
    xpack.security.loginAssistanceMessage
    xpack.security.sameSiteCookies
    xpack.security.secureCookies
    xpack.security.sessionTimeout
    xpack.security.session.idleTimeout
    xpack.security.session.lifespan
    xpack.security.session.cleanupInterval
    xpack.security.loginAssistanceMessage
    xpack.security.loginHelp
    xpack.security.public.protocol
    xpack.security.public.hostname
    xpack.security.public.port
    xpack.spaces.enabled
    xpack.spaces.maxSpaces
    telemetry.allowChangingOptInStatus
    telemetry.enabled
    telemetry.optIn
    telemetry.optInStatusUrl
    telemetry.sendUsageFrom
)

longopts=''
for kibana_var in ${kibana_vars[*]}; do
    # 'elasticsearch.hosts' -> 'ELASTICSEARCH_HOSTS'
    env_var=$(echo ${kibana_var^^} | tr . _)

    # Indirectly lookup env var values via the name of the var.
    # REF: http://tldp.org/LDP/abs/html/bashver2.html#EX78
    value=${!env_var:-}
    if [[ -n $value ]]; then
      longopt="--${kibana_var}=${value}"
      longopts+=" ${longopt}"
    fi
done

# Allow root so we can bind to 443 in the container IF ASKED TO
# Note that this does not work for elastic and there is no apparent way to work around it
kibana --allow-root ${longopts} "$@"
