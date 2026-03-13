resource "scaleway_vpc" "main" {
  name   = "climacterium-vpc"
  tags   = ["climacterium"]
  region = var.region
}

resource "scaleway_vpc_private_network" "main" {
  name   = "climacterium-private-network"
  vpc_id = scaleway_vpc.main.id
  region = var.region
}
