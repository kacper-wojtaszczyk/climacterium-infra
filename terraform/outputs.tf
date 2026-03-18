output "cluster_id" {
  description = "Kapsule cluster ID"
  value       = scaleway_k8s_cluster.main.id
}

output "kubeconfig" {
  description = "Full kubeconfig for kubectl access — contains cluster credentials"
  value       = scaleway_k8s_cluster.main.kubeconfig[0].config_file
  sensitive   = true
}

output "registry_endpoint" {
  description = "Container Registry endpoint for image tagging"
  value       = scaleway_registry_namespace.main.endpoint
}

output "postgres_host" {
  description = "PostgreSQL private network host IP"
  value       = scaleway_rdb_instance.postgres.private_network[0].ip
}

output "postgres_port" {
  description = "PostgreSQL port"
  value       = scaleway_rdb_instance.postgres.private_network[0].port
}

output "postgres_connection_string" {
  description = "PostgreSQL connection string (contains credentials)"
  value = format(
    "postgresql://%s:%s@%s:%s/postgres?sslmode=require",
    scaleway_rdb_user.admin.name,
    var.postgres_password,
    scaleway_rdb_instance.postgres.private_network[0].ip,
    tostring(scaleway_rdb_instance.postgres.private_network[0].port),
  )
  sensitive = true
}

output "s3_access_key" {
  description = "S3 access key ID for jackfruit-raw bucket"
  value       = scaleway_iam_api_key.pipeline.access_key
  sensitive   = true
}

output "s3_secret_key" {
  description = "S3 secret key for jackfruit-raw bucket"
  value       = scaleway_iam_api_key.pipeline.secret_key
  sensitive   = true
}

output "s3_bucket_name" {
  description = "Object Storage bucket name"
  value       = scaleway_object_bucket.jackfruit_raw.name
}

output "s3_endpoint" {
  description = "S3-compatible endpoint URL"
  value       = "https://s3.${var.region}.scw.cloud"
}

output "lb_id" {
  value       = scaleway_lb.main.id
  description = "Zoned ID of the Load Balancer (needed for K8s CCM annotation)"
}

output "lb_ip" {
  value       = scaleway_lb_ip.main.ip_address
  description = "Public IPv4 of the Load Balancer"
}

output "lb_certificate_id" {
  value       = scaleway_lb_certificate.buttprint.id
  description = "Zoned ID of the TLS certificate (needed for K8s CCM annotation)"
}
