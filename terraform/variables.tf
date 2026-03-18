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
  description = "Admin password for the jackfruit-postgres RDB instance"
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

variable "acme_email" {
  type        = string
  description = "Email address for Let's Encrypt ACME registration"
}
