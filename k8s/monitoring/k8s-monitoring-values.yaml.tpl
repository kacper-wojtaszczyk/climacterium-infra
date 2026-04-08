cluster:
  name: climacterium

destinations:
  cockpit-logs:
    type: loki
    url: ${cockpit_push_url}
    auth:
      type: bearerToken
      bearerTokenKey: token
    secret:
      create: false
      name: cockpit-credentials

collectors:
  alloy:
    presets:
      - daemonset
      - filesystem-log-reader

podLogsViaLoki:
  enabled: true

clusterEvents:
  enabled: true

nodeLogs:
  enabled: true

selfReporting:
  enabled: false
