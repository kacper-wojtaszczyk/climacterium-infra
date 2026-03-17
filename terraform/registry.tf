resource "scaleway_registry_namespace" "main" {
  name      = "climacterium"
  is_public = false
  region    = var.region
}

output "registry_endpoint" {
  description = "Container Registry endpoint for image tagging"
  value       = scaleway_registry_namespace.main.endpoint
}
