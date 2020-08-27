#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

export LOGGING_DEST=/dev/stdout
export PID_FILE=/data/kibana.pid
export PATH_DATA=/data/data

kibana_vars=(
    console.enabled
    console.proxyConfig
    console.proxyFilter
    elasticsearch.customHeaders
    elasticsearch.hosts
    elasticsearch.logQueries
    elasticsearch.password
    elasticsearch.pingTimeout
    elasticsearch.preserveHost
    elasticsearch.requestHeadersWhitelist
    elasticsearch.requestTimeout
    elasticsearch.shardTimeout
    elasticsearch.sniffInterval
    elasticsearch.sniffOnConnectionFault
    elasticsearch.sniffOnStart
    elasticsearch.ssl.certificate
    elasticsearch.ssl.certificateAuthorities
    elasticsearch.ssl.key
    elasticsearch.ssl.keyPassphrase
    elasticsearch.ssl.verificationMode
    elasticsearch.startupTimeout
    elasticsearch.username
    i18n.locale
    kibana.defaultAppId
    kibana.index
    logging.dest
    logging.quiet
    logging.silent
    logging.useUTC
    logging.verbose
    map.includeElasticMapsService
    ops.interval
    path.data
    pid.file
    regionmap
    regionmap.includeElasticMapsService
    server.basePath
    server.customResponseHeaders
    server.defaultRoute
    server.host
    server.maxPayloadBytes
    server.name
    server.port
    server.rewriteBasePath
    server.ssl.cert
    server.ssl.certificate
    server.ssl.certificateAuthorities
    server.ssl.cipherSuites
    server.ssl.clientAuthentication
    server.customResponseHeaders
    server.ssl.enabled
    server.ssl.key
    server.ssl.keyPassphrase
    server.ssl.redirectHttpFromPort
    server.ssl.supportedProtocols
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
    xpack.apm.enabled
    xpack.apm.ui.enabled
    xpack.apm.ui.maxTraceItems
    apm_oss.apmAgentConfigurationIndex
    apm_oss.indexPattern
    apm_oss.errorIndices
    apm_oss.onboardingIndices
    apm_oss.spanIndices
    apm_oss.transactionIndices
    apm_oss.metricsIndices
    xpack.canvas.enabled
    xpack.graph.enabled
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
    xpack.ml.enabled
    xpack.monitoring.elasticsearch.password
    xpack.monitoring.elasticsearch.pingTimeout
    xpack.monitoring.elasticsearch.hosts
    xpack.monitoring.elasticsearch.username
    xpack.monitoring.elasticsearch.ssl.certificateAuthorities
    xpack.monitoring.elasticsearch.ssl.verificationMode
    xpack.monitoring.enabled
    xpack.monitoring.kibana.collection.enabled
    xpack.monitoring.kibana.collection.interval
    xpack.monitoring.max_bucket_size
    xpack.monitoring.min_interval_seconds
    xpack.monitoring.node_resolver
    xpack.monitoring.report_stats
    xpack.monitoring.elasticsearch.pingTimeout
    xpack.monitoring.ui.container.elasticsearch.enabled
    xpack.monitoring.ui.container.logstash.enabled
    xpack.monitoring.ui.enabled
    xpack.reporting.capture.browser.chromium.disableSandbox
    xpack.reporting.capture.browser.chromium.proxy.enabled
    xpack.reporting.capture.browser.chromium.proxy.server
    xpack.reporting.capture.browser.chromium.proxy.bypass
    xpack.reporting.capture.browser.type
    xpack.reporting.capture.concurrency
    xpack.reporting.capture.loadDelay
    xpack.reporting.capture.settleTime
    xpack.reporting.capture.timeout
    xpack.reporting.csv.maxSizeBytes
    xpack.reporting.enabled
    xpack.reporting.encryptionKey
    xpack.reporting.index
    xpack.reporting.kibanaApp
    xpack.reporting.kibanaServer.hostname
    xpack.reporting.kibanaServer.port
    xpack.reporting.kibanaServer.protocol
    xpack.reporting.queue.indexInterval
    xpack.reporting.queue.pollInterval
    xpack.reporting.queue.timeout
    xpack.reporting.roles.allow
    xpack.searchprofiler.enabled
    xpack.security.authProviders
    xpack.security.authc.providers
    xpack.security.authc.oidc.realm
    xpack.security.authc.saml.realm
    xpack.security.cookieName
    xpack.security.enabled
    xpack.security.encryptionKey
    xpack.security.secureCookies
    xpack.security.sessionTimeout
    xpack.security.public.protocol
    xpack.security.public.hostname
    xpack.security.public.port
    xpack.telemetry.enabled
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

# Files created at run-time should be group-writable, for Openshift's sake.
umask 0002

# The virtual file /proc/self/cgroup should list the current cgroup
# membership. For each hierarchy, you can follow the cgroup path from
# this file to the cgroup filesystem (usually /sys/fs/cgroup/) and
# introspect the statistics for the cgroup for the given
# hierarchy. Alas, Docker breaks this by mounting the container
# statistics at the root while leaving the cgroup paths as the actual
# paths. Therefore, Kibana provides a mechanism to override
# reading the cgroup path from /proc/self/cgroup and instead uses the
# cgroup path defined the configuration properties
# cpu.cgroup.path.override and cpuacct.cgroup.path.override.
# Therefore, we set this value here so that cgroup statistics are
# available for the container this process will run in.

exec kibana --cpu.cgroup.path.override=/ --cpuacct.cgroup.path.override=/ ${longopts} "$@"