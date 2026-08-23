cluster:
  name: climacterium

destinations:
  cockpit-logs:
    type: loki
    url: "${cockpit_push_url}"
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
    alloy:
      # Without a limit the log tailer's page cache grows unbounded (observed
      # ~730Mi working set for a ~190Mi RSS process). A limit bounds the cgroup
      # cache and makes Alloy auto-set GOMEMLIMIT to 90% of it (INF-12).
      resources:
        requests:
          cpu: 50m
          memory: 128Mi
        limits:
          cpu: 200m
          memory: 384Mi

podLogsViaLoki:
  enabled: true

clusterEvents:
  enabled: true

# Node systemd-journal logs (kubelet/containerd units) — unused in Cockpit;
# disabled to cut tailing churn and ingestion volume (INF-12).
nodeLogs:
  enabled: false

selfReporting:
  enabled: false
