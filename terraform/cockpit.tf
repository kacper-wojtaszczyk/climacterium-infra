resource "scaleway_cockpit_source" "logs" {
  project_id     = var.project_id
  name           = "production-logs"
  type           = "logs"
  retention_days = 7
}

resource "scaleway_cockpit_token" "alloy" {
  project_id = var.project_id
  name       = "alloy-log-push"

  scopes {
    query_metrics       = false
    write_metrics       = false
    setup_metrics_rules = false
    query_logs          = false
    write_logs          = true
    setup_logs_rules    = false
    setup_alerts        = false
    query_traces        = false
    write_traces        = false
  }
}
