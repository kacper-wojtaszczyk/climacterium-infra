resource "scaleway_lb_ip" "main" {}

resource "scaleway_lb" "main" {
  ip_ids = [scaleway_lb_ip.main.id]
  name   = "climacterium-lb"
  type   = "LB-S"

  tags = ["environment:production", "project:climacterium"]
}

resource "acme_registration" "main" {
  email_address = var.acme_email
}

resource "acme_certificate" "buttprint" {
  account_key_pem           = acme_registration.main.account_key_pem
  common_name               = "buttprint.eu"
  subject_alternative_names = ["api.buttprint.eu", "dagster.buttprint.eu"]

  dns_challenge {
    provider = "scaleway"
    config = {
      SCW_SECRET_KEY = var.scw_secret_key
      SCW_PROJECT_ID = var.project_id
    }
  }
}

resource "scaleway_lb_certificate" "buttprint" {
  lb_id = scaleway_lb.main.id
  name  = "buttprint-tls"

  custom_certificate {
    certificate_chain = "${acme_certificate.buttprint.private_key_pem}${acme_certificate.buttprint.certificate_pem}${acme_certificate.buttprint.issuer_pem}"
  }

  lifecycle {
    create_before_destroy = true
  }
}
