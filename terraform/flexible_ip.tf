# This IP survives node replacement. The provider cannot configure its server_id;
# attach it to a Ready Kapsule node using the CLI runbook in README.md.
resource "scaleway_instance_ip" "ingress" {
  type       = "routed_ipv4"
  zone       = var.zone
  project_id = var.project_id
}