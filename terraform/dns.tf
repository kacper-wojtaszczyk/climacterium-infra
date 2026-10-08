resource "scaleway_domain_zone" "buttprint" {
  domain    = "buttprint.eu"
  subdomain = ""
}

resource "scaleway_domain_record" "root" {
  dns_zone = scaleway_domain_zone.buttprint.id
  name     = ""
  type     = "A"
  data     = scaleway_instance_ip.ingress.address
  ttl      = 300
}

resource "scaleway_domain_record" "api" {
  dns_zone = scaleway_domain_zone.buttprint.id
  name     = "api"
  type     = "A"
  data     = scaleway_instance_ip.ingress.address
  ttl      = 300
}

resource "scaleway_domain_record" "dagster" {
  dns_zone = scaleway_domain_zone.buttprint.id
  name     = "dagster"
  type     = "A"
  data     = scaleway_instance_ip.ingress.address
  ttl      = 300
}
