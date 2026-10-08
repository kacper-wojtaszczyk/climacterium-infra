# cert-manager installs its CRDs; the local buttprint-tls Helm chart below
# creates the ClusterIssuer and Certificate after both controllers are installed.
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  chart            = "cert-manager"
  repository       = "https://charts.jetstack.io"
  version          = "v1.19.1"
  atomic           = true
  timeout          = 300

  values = [jsonencode({
    crds = { enabled = true }
    resources = {
      requests = {
        cpu    = "50m"
        memory = "64Mi"
      }
      limits = {
        cpu    = "200m"
        memory = "256Mi"
      }
    }
  })]

  depends_on = [scaleway_k8s_pool.services]
}

# nginx terminates TLS on each node's ports 80/443; no LoadBalancer Service.
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
      { ingress_ip = scaleway_instance_ip.ingress.address }
    )
  ]

  depends_on = [scaleway_k8s_pool.services]
}

resource "helm_release" "buttprint_tls" {
  name      = "buttprint-tls"
  namespace = "default"
  chart     = "${path.module}/../k8s/cert-manager"
  atomic    = true
  timeout   = 300

  values = [jsonencode({ acmeEmail = var.acme_email })]

  depends_on = [helm_release.cert_manager, helm_release.ingress_nginx]
}

# Bootstrap order for a clean apply from empty state:
#   1. terraform apply -target=scaleway_k8s_cluster.main -target=scaleway_k8s_pool.services
#   2. scw k8s kubeconfig install <cluster-id>
#   3. ./scripts/sync-secrets.sh  (creates cockpit-credentials, referenced by k8s_monitoring)
#   4. terraform apply  (installs all Helm releases; cert-manager before buttprint-tls)
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