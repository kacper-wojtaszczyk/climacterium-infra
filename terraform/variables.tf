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
