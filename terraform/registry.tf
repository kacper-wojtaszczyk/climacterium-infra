resource "scaleway_registry_namespace" "main" {
  name      = "climacterium"
  is_public = false
  region    = var.region
}
