resource "scaleway_k8s_cluster" "main" {
  name    = "climacterium"
  version = "1.35.2"
  cni     = "cilium"
  type    = "kapsule"

  private_network_id = scaleway_vpc_private_network.main.id

  autoscaler_config {
    scale_down_delay_after_add = "5m"
    scale_down_unneeded_time   = "10m"
  }

  tags = ["climacterium"]
  delete_additional_resources = false
}

resource "scaleway_k8s_pool" "services" {
  cluster_id  = scaleway_k8s_cluster.main.id
  name        = "services"
  node_type   = "BASIC2-A2C-4G"
  size        = 1
  min_size    = 1
  max_size    = 2
  autoscaling = true
  autohealing = true
}

resource "scaleway_k8s_pool" "jobs" {
  cluster_id  = scaleway_k8s_cluster.main.id
  name        = "jobs"
  node_type   = "BASIC2-A2C-4G"
  size        = 0
  min_size    = 0
  max_size    = 2
  autoscaling = true
  autohealing = true
  tags = ["taint=workload=batch:NoSchedule"]
}
