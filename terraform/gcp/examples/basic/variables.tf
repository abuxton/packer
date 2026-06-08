variable "project_id" {
  type        = string
  description = "GCP project ID for example resources."
}

variable "region" {
  type        = string
  description = "GCP region for example resources."
  default     = "us-central1"
}

variable "subnetwork" {
  type        = string
  description = "Subnetwork self-link for MIG instances."
}

variable "dns_managed_zone" {
  type        = string
  description = "Cloud DNS managed zone name."
}

variable "dns_name" {
  type        = string
  description = "DNS record name with trailing dot (e.g. `mirror.example.com.`)."
}
