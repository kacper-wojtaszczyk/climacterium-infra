resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  chart            = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  version          = "4.15.0"
  atomic           = true
  timeout          = 600

  values = [
    templatefile(
      "${path.module}/../k8s/ingress-nginx-values.yaml.tpl",
      {
        lb_id      = scaleway_lb.main.id
        lb_cert_id = scaleway_lb_certificate.buttprint.id
      }
    )
  ]

  depends_on = [scaleway_k8s_pool.services]
}

# Bootstrap order for a clean apply from empty state:
#   1. terraform apply -target=scaleway_k8s_cluster.main -target=scaleway_k8s_pool.services
#   2. scw k8s kubeconfig install <cluster-id>
#   3. ./scripts/sync-secrets.sh  (creates cockpit-credentials, referenced by k8s_monitoring)
#   4. terraform apply            (installs helm_releases; k8s_monitoring requires the secret)
resource "helm_release" "k8s_monitoring" {
  name       = "k8s-monitoring"
  namespace  = "default"
  chart      = "k8s-monitoring"
  repository = "https://grafana.github.io/helm-charts"
  version    = "4.0.0"
  atomic     = true
  timeout    = 600

  values = [
    templatefile(
      "${path.module}/../k8s/monitoring/k8s-monitoring-values.yaml.tpl",
      {
        cockpit_push_url = scaleway_cockpit_source.logs.push_url
      }
    )
  ]

  depends_on = [scaleway_k8s_pool.services]
}
