variable "project_id" {
  type        = string
  description = "Scaleway project ID"
}

variable "region" {
  type        = string
  description = "Scaleway region"
  default     = "nl-ams"
}

variable "zone" {
  type        = string
  description = "Scaleway availability zone"
  default     = "nl-ams-1"
}

variable "postgres_password" {
  type        = string
  description = "Password for the in-cluster PostgreSQL StatefulSet (injected into postgres-credentials by sync-secrets.sh)"
  sensitive   = true
}

variable "clickhouse_password" {
  type        = string
  description = "Password for the ClickHouse default user (self-hosted in K8s)"
  sensitive   = true
}

variable "scw_secret_key" {
  type        = string
  description = "Scaleway secret key — passed to ACME provider for DNS-01 challenge via Scaleway DNS"
  sensitive   = true
}

variable "ads_api_key" {
  type        = string
  description = "Copernicus ADS API key for climate data downloads"
  sensitive   = true
}

variable "acme_email" {
  type        = string
  description = "Email address for Let's Encrypt ACME registration"
}

variable "dagster_webserver_password" {
  type        = string
  description = "Password for Dagster webserver Basic Auth (username: dagster)"
  sensitive   = true
}

variable "kubeconfig_path" {
  description = "Path to the kubeconfig file the Helm provider should use"
  type        = string
  default     = "~/.kube/config"
}
