#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)"
readonly root
# shellcheck source=/dev/null
source "$root/helpers.sh"
# shellcheck source=/dev/null
source "$root/mdns.sh"

helpers::dir::writable "/certs"
helpers::dir::writable "$XDG_DATA_HOME" create
helpers::dir::writable "$XDG_DATA_DIRS" create
helpers::dir::writable "$XDG_RUNTIME_DIR" create
helpers::dir::writable "$XDG_STATE_HOME" create
helpers::dir::writable "$XDG_CACHE_HOME" create

# mDNS blast if asked to
[ ! "${MDNS_HOST:-}" ] || {
  _mdns_port="$([ "$TLS" != "" ] && printf "%s" "${ADVANCED_PORT_HTTPS:-443}" || printf "%s" "${ADVANCED_PORT_HTTP:-80}")"
  [ ! "${MDNS_STATION:-}" ] || mdns::records::add "_workstation._tcp" "$MDNS_HOST" "${MDNS_NAME:-}" "$_mdns_port"
  mdns::records::add "${MDNS_TYPE:-_http._tcp}" "$MDNS_HOST" "${MDNS_NAME:-}" "$_mdns_port"
  mdns::records::broadcast &
}

# Start the sidecar
start::sidecar &

# This is in the official dockerfile, so...
export ELASTIC_CONTAINER=true

# Options we set
export XPACK_SECURITY_ENABLED=true
export XPACK_REPORTING_CAPTURE_BROWSER_CHROMIUM_DISABLESANDBOX=true
export MONITORING_UI_CONTAINER_ELASTICSEARCH_ENABLED=true
export OPS_CGROUPOVERRIDES_CPUPATH=/
export OPS_CGROUPOVERRIDES_CPUACCTPATH=/
export LOGGING_DEST=/dev/stdout
export PATH_DATA=$XDG_DATA_DIRS/kibana
export SERVER_PORT=10042
export SERVER_NAME=kibana
export SERVER_HOST=127.0.0.1
export SERVER_SHUTDOWNTIMEOUT="5s"
export SERVER_PUBLICBASEURL=https://DOMAIN:443
export PID_FILE="$XDG_RUNTIME_DIR/kibana.pid"
rm -f "$PID_FILE"

# With 7.14: https://github.com/elastic/dockerfiles/blob/7.14/kibana/bin/kibana-docker
kibana_vars=(
    apm_oss.apmAgentConfigurationIndex
    apm_oss.errorIndices
    apm_oss.indexPattern
    apm_oss.metricsIndices
    apm_oss.onboardingIndices
    apm_oss.sourcemapIndices
    apm_oss.spanIndices
    apm_oss.transactionIndices
    console.enabled
    console.proxyConfig
    console.proxyFilter
    cpu.cgroup.path.override
    cpuacct.cgroup.path.override
    csp.rules
    csp.strict
    csp.warnLegacyBrowsers
    csp.script_src
    csp.worker_src
    csp.style_src
    csp.connect_src
    csp.default_src
    csp.font_src
    csp.frame_src
    csp.img_src
    csp.frame_ancestors
    csp.report_uri
    csp.report_to
    data.autocomplete.valueSuggestions.terminateAfter
    data.autocomplete.valueSuggestions.timeout
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
    elasticsearch.ssl.keystore.password
    elasticsearch.ssl.keystore.path
    elasticsearch.ssl.truststore.password
    elasticsearch.ssl.truststore.path
    elasticsearch.ssl.verificationMode
    elasticsearch.username
    enterpriseSearch.accessCheckTimeout
    enterpriseSearch.accessCheckTimeoutWarning
    enterpriseSearch.enabled
    enterpriseSearch.host
    externalUrl.policy
    i18n.locale
    interpreter.enableInVisualize
    kibana.autocompleteTerminateAfter
    kibana.autocompleteTimeout
    kibana.defaultAppId
    kibana.index
    logging.appenders
    logging.appenders.console
    logging.appenders.file
    logging.dest
    logging.json
    logging.loggers
    logging.loggers.appenders
    logging.loggers.level
    logging.loggers.name
    logging.quiet
    logging.root
    logging.root.appenders
    logging.root.level
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
    migrations.batchSize
    migrations.enableV2
    migrations.pollInterval
    migrations.retryAttempts
    migrations.scrollDuration
    migrations.skip
    monitoring.cluster_alerts.email_notifications.email_address
    monitoring.enabled
    monitoring.kibana.collection.enabled
    monitoring.kibana.collection.interval
    monitoring.ui.container.elasticsearch.enabled
    monitoring.ui.container.logstash.enabled
    monitoring.ui.elasticsearch.hosts
    monitoring.ui.elasticsearch.logFetchCount
    monitoring.ui.elasticsearch.password
    monitoring.ui.elasticsearch.pingTimeout
    monitoring.ui.elasticsearch.ssl.certificateAuthorities
    monitoring.ui.elasticsearch.ssl.verificationMode
    monitoring.ui.elasticsearch.username
    monitoring.ui.enabled
    monitoring.ui.logs.index
    monitoring.ui.max_bucket_size
    monitoring.ui.min_interval_seconds
    newsfeed.enabled
    ops.cGroupOverrides.cpuAcctPath
    ops.cGroupOverrides.cpuPath
    ops.interval
    path.data
    pid.file
    regionmap
    savedObjects.maxImportExportSize
    savedObjects.maxImportPayloadBytes
    security.showInsecureClusterWarning
    server.basePath
    server.compression.enabled
    server.compression.referrerWhitelist
    server.cors
    server.cors.allowCredentials
    server.cors.allowOrigin
    server.cors.enabled
    server.cors.origin
    server.customResponseHeaders
    server.defaultRoute
    server.host
    server.keepAliveTimeout
    server.maxPayload
    server.maxPayloadBytes
    server.name
    server.port
    server.publicBaseUrl
    server.requestId.allowFromAnyIp
    server.requestId.ipAllowlist
    server.rewriteBasePath
    server.securityResponseHeaders.disableEmbedding
    server.securityResponseHeaders.permissionsPolicy
    server.securityResponseHeaders.referrerPolicy
    server.securityResponseHeaders.strictTransportSecurity
    server.securityResponseHeaders.xContentTypeOptions
    server.shutdownTimeout
    server.socketTimeout
    server.ssl.cert
    server.ssl.certificate
    server.ssl.certificateAuthorities
    server.ssl.cipherSuites
    server.ssl.clientAuthentication
    server.ssl.enabled
    server.ssl.key
    server.ssl.keyPassphrase
    server.ssl.keystore.password
    server.ssl.keystore.path
    server.ssl.redirectHttpFromPort
    server.ssl.supportedProtocols
    server.ssl.truststore.password
    server.ssl.truststore.path
    server.uuid
    server.xsrf.allowlist
    server.xsrf.disableProtection
    server.xsrf.whitelist
    status.allowAnonymous
    status.v6ApiFormat
    telemetry.allowChangingOptInStatus
    telemetry.enabled
    telemetry.optIn
    telemetry.optInStatusUrl
    telemetry.sendUsageFrom
    tilemap.options.attribution
    tilemap.options.maxZoom
    tilemap.options.minZoom
    tilemap.options.subdomains
    tilemap.url
    timelion.enabled
    url_drilldown.enabled
    vega.enableExternalUrls
    vis_type_vega.enableExternalUrls
    xpack.actions.allowedHosts
    xpack.actions.customHostSettings
    xpack.actions.enabled
    xpack.actions.enabledActionTypes
    xpack.actions.maxResponseContentLength
    xpack.actions.preconfigured
    xpack.actions.preconfiguredAlertHistoryEsIndex
    xpack.actions.proxyBypassHosts
    xpack.actions.proxyHeaders
    xpack.actions.proxyOnlyHosts
    xpack.actions.proxyRejectUnauthorizedCertificates
    xpack.actions.proxyUrl
    xpack.actions.rejectUnauthorized
    xpack.actions.responseTimeout
    xpack.actions.ssl.proxyVerificationMode
    xpack.actions.ssl.verificationMode
    xpack.alerting.healthCheck.interval
    xpack.alerting.invalidateApiKeysTask.interval
    xpack.alerting.invalidateApiKeysTask.removalDelay
    xpack.alerts.healthCheck.interval
    xpack.alerts.invalidateApiKeysTask.interval
    xpack.alerts.invalidateApiKeysTask.removalDelay
    xpack.apm.enabled
    xpack.apm.maxServiceEnvironments
    xpack.apm.searchAggregatedTransactions
    xpack.apm.serviceMapEnabled
    xpack.apm.serviceMapFingerprintBucketSize
    xpack.apm.serviceMapFingerprintGlobalBucketSize
    xpack.apm.ui.enabled
    xpack.apm.ui.maxTraceItems
    xpack.apm.ui.transactionGroupBucketSize
    xpack.banners.backgroundColor
    xpack.banners.disableSpaceBanners
    xpack.banners.placement
    xpack.banners.textColor
    xpack.banners.textContent
    xpack.canvas.enabled
    xpack.code.disk.thresholdEnabled
    xpack.code.disk.watermarkLow
    xpack.code.indexRepoFrequencyMs
    xpack.code.lsp.verbose
    xpack.code.maxWorkspace
    xpack.code.security.enableGitCertCheck
    xpack.code.security.gitHostWhitelist
    xpack.code.security.gitProtocolWhitelist
    xpack.code.ui.enabled
    xpack.code.updateRepoFrequencyMs
    xpack.code.verbose
    xpack.data_enhanced.search.sessions.defaultExpiration
    xpack.data_enhanced.search.sessions.enabled
    xpack.data_enhanced.search.sessions.maxUpdateRetries
    xpack.data_enhanced.search.sessions.notTouchedInProgressTimeout
    xpack.data_enhanced.search.sessions.notTouchedTimeout
    xpack.data_enhanced.search.sessions.pageSize
    xpack.data_enhanced.search.sessions.trackingInterval
    xpack.discoverEnhanced.actions.exploreDataInChart.enabled
    xpack.discoverEnhanced.actions.exploreDataInContextMenu.enabled
    xpack.encryptedSavedObjects.encryptionKey
    xpack.encryptedSavedObjects.keyRotation.decryptionOnlyKeys
    xpack.event_log.enabled
    xpack.event_log.indexEntries
    xpack.event_log.logEntries
    xpack.fleet.agentPolicies
    xpack.fleet.agents.elasticsearch.host
    xpack.fleet.agents.elasticsearch.hosts
    xpack.fleet.agents.enabled
    xpack.fleet.agents.fleet_server.hosts
    xpack.fleet.agents.kibana.host
    xpack.fleet.agents.tlsCheckDisabled
    xpack.fleet.enabled
    xpack.fleet.packages
    xpack.fleet.registryUrl
    xpack.graph.canEditDrillDownUrls
    xpack.graph.enabled
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
    xpack.observability.annotations.index
    xpack.observability.unsafe.alertingExperience.enabled
    xpack.observability.unsafe.cases.enabled
    xpack.painless_lab.enabled
    xpack.reporting.capture.browser.autoDownload
    xpack.reporting.capture.browser.chromium.disableSandbox
    xpack.reporting.capture.browser.chromium.inspect
    xpack.reporting.capture.browser.chromium.maxScreenshotDimension
    xpack.reporting.capture.browser.chromium.proxy.bypass
    xpack.reporting.capture.browser.chromium.proxy.enabled
    xpack.reporting.capture.browser.chromium.proxy.server
    xpack.reporting.capture.browser.type
    xpack.reporting.capture.concurrency
    xpack.reporting.capture.loadDelay
    xpack.reporting.capture.maxAttempts
    xpack.reporting.capture.networkPolicy
    xpack.reporting.capture.settleTime
    xpack.reporting.capture.timeout
    xpack.reporting.capture.timeouts.openUrl
    xpack.reporting.capture.timeouts.openUrl
    xpack.reporting.capture.timeouts.renderComplete
    xpack.reporting.capture.timeouts.waitForElements
    xpack.reporting.capture.viewport.height
    xpack.reporting.capture.viewport.width
    xpack.reporting.capture.zoom
    xpack.reporting.csv.checkForFormulas
    xpack.reporting.csv.enablePanelActionDownload
    xpack.reporting.csv.escapeFormulaValues
    xpack.reporting.csv.maxSizeBytes
    xpack.reporting.csv.scroll.duration
    xpack.reporting.csv.scroll.size
    xpack.reporting.csv.useByteOrderMarkEncoding
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
    xpack.reporting.roles.enabled
    xpack.rollup.enabled
    xpack.ruleRegistry.write.enabled
    xpack.searchprofiler.enabled
    xpack.security.audit.appender.fileName
    xpack.security.audit.appender.layout.highlight
    xpack.security.audit.appender.layout.pattern
    xpack.security.audit.appender.layout.type
    xpack.security.audit.appender.legacyLoggingConfig
    xpack.security.audit.appender.policy.interval
    xpack.security.audit.appender.policy.modulate
    xpack.security.audit.appender.policy.size
    xpack.security.audit.appender.policy.type
    xpack.security.audit.appender.strategy.max
    xpack.security.audit.appender.strategy.pattern
    xpack.security.audit.appender.strategy.type
    xpack.security.audit.appender.type
    xpack.security.audit.enabled
    xpack.security.audit.ignore_filters
    xpack.security.authc.http.autoSchemesEnabled
    xpack.security.authc.http.enabled
    xpack.security.authc.http.schemes
    xpack.security.authc.oidc.realm
    xpack.security.authc.providers
    xpack.security.authc.saml.maxRedirectURLSize
    xpack.security.authc.saml.realm
    xpack.security.authc.selector.enabled
    xpack.security.authProviders
    xpack.security.cookieName
    xpack.security.enabled
    xpack.security.encryptionKey
    xpack.security.loginAssistanceMessage
    xpack.security.loginAssistanceMessage
    xpack.security.loginHelp
    xpack.security.public.hostname
    xpack.security.public.port
    xpack.security.public.protocol
    xpack.security.sameSiteCookies
    xpack.security.secureCookies
    xpack.security.session.cleanupInterval
    xpack.security.session.idleTimeout
    xpack.security.session.lifespan
    xpack.security.sessionTimeout
    xpack.securitySolution.alertMergeStrategy
    xpack.securitySolution.alertResultListDefaultDateRange
    xpack.securitySolution.alertIgnoreFields
    xpack.securitySolution.endpointResultListDefaultFirstPageIndex
    xpack.securitySolution.endpointResultListDefaultPageSize
    xpack.securitySolution.maxRuleImportExportSize
    xpack.securitySolution.maxRuleImportPayloadBytes
    xpack.securitySolution.maxTimelineImportExportSize
    xpack.securitySolution.maxTimelineImportPayloadBytes
    xpack.securitySolution.packagerTaskInterval
    xpack.securitySolution.validateArtifactDownloads
    xpack.securitySolution.prebuiltRulesFromFileSystem
    xpack.securitySolution.prebuiltRulesFromSavedObjects
    xpack.spaces.enabled
    xpack.spaces.maxSpaces
    xpack.task_manager.enabled
    xpack.task_manager.index
    xpack.task_manager.max_attempts
    xpack.task_manager.max_poll_inactivity_cycles
    xpack.task_manager.max_workers
    xpack.task_manager.monitored_aggregated_stats_refresh_rate
    xpack.task_manager.monitored_stats_required_freshness
    xpack.task_manager.monitored_stats_running_average_window
    xpack.task_manager.monitored_stats_health_verbose_log.enabled
    xpack.task_manager.monitored_stats_health_verbose_log.warn_delayed_task_start_in_seconds
    xpack.task_manager.monitored_task_execution_thresholds
    xpack.task_manager.poll_interval
    xpack.task_manager.request_capacity
    xpack.task_manager.version_conflict_threshold
)

longopts=()
for kibana_var in ${kibana_vars[*]}; do
    env_var=$(echo ${kibana_var^^} | tr . _)
    value=${!env_var:-}
    if [[ -n $value ]]; then
      longopts+=("--${kibana_var}=${value}")
    fi
done

exec kibana serve "${longopts[@]}" "$@"
