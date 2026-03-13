output "cluster_id" {
  description = "Kapsule cluster ID"
  value       = scaleway_k8s_cluster.main.id
}

output "kubeconfig" {
  description = "Full kubeconfig for kubectl access — contains cluster credentials"
  value       = scaleway_k8s_cluster.main.kubeconfig[0].config_file
  sensitive   = true
}
