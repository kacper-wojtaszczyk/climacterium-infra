terraform {
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.0"
    }
    acme = {
      source  = "vancluever/acme"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.5"
}

provider "scaleway" {
  project_id = var.project_id
  region     = var.region
}

provider "acme" {
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}

provider "helm" {
  kubernetes = {
    config_path = pathexpand(var.kubeconfig_path)
  }
}
