# Kapsule's default security group drops all inbound traffic. Direct ingress
# needs the HTTP-01 challenge port and HTTPS reachable on the node's public IP.
resource "scaleway_instance_security_group" "kapsule_ingress" {
  name                    = "climacterium-kapsule-ingress"
  description             = "Kapsule nodes: public ingress on HTTP and HTTPS"
  inbound_default_policy  = "drop"
  outbound_default_policy = "accept"
  zone                    = var.zone
  project_id              = var.project_id

  inbound_rule {
    action   = "accept"
    protocol = "TCP"
    port     = 80
    ip_range = "0.0.0.0/0"
  }

  inbound_rule {
    action   = "accept"
    protocol = "TCP"
    port     = 443
    ip_range = "0.0.0.0/0"
  }
}
