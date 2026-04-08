import {
  to = helm_release.ingress_nginx
  id = "ingress-nginx/ingress-nginx"
}

import {
  to = helm_release.k8s_monitoring
  id = "default/k8s-monitoring"
}

resource "helm_release" "k8s_monitoring" {
  name                       = "k8s-monitoring"
  namespace                  = "default"
  chart                      = "k8s-monitoring"
  repository                 = "https://grafana.github.io/helm-charts"
  version                    = "4.0.0"
  values = [
    templatefile(
      "${path.module}/../k8s/monitoring/k8s-monitoring-values.yaml.tpl",
      {
        cockpit_push_url = scaleway_cockpit_source.logs.push_url
      }
    )
  ]
}

resource "helm_release" "ingress_nginx" {
  name                       = "ingress-nginx"
  namespace                  = "ingress-nginx"
  chart                      = "ingress-nginx"
  repository                 = "https://kubernetes.github.io/ingress-nginx"
  version                    = "4.15.0"
  values                     = [
    templatefile(
      "${path.module}/../k8s/ingress-nginx-values.yaml.tpl",
      {
        lb_id      = scaleway_lb.main.id
        lb_cert_id = scaleway_lb_certificate.buttprint.id
      }
    )
  ]
}
