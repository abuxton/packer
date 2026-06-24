variable "project_id" {
  type        = string
  description = "GCP project ID in which all resources are created."
}

variable "name" {
  type        = string
  description = "Base name prefix applied to all resources created by this module."
  default     = "ubuntu-docker-mirror"
}

variable "region" {
  type        = string
  description = "GCP region for the regional Managed Instance Group and related resources."
  default     = "us-central1"
}

variable "image_family" {
  type        = string
  description = "Compute Engine image family used to resolve the latest ubuntu-docker-mirror image built by Packer."
  default     = "ubuntu-docker-mirror"
}

variable "image_project" {
  type        = string
  description = "GCP project that owns the Packer-built image family. Defaults to `project_id`."
  default     = ""
}

variable "machine_type" {
  type        = string
  description = "Compute Engine machine type for instances in the Managed Instance Group."
  default     = "e2-standard-2"
}

variable "subnetwork" {
  type        = string
  description = "Self-link or name of the subnetwork in which MIG instances are placed."
}

variable "subnetwork_project" {
  type        = string
  description = "Project ID for the subnetwork (required when using a shared VPC). Defaults to `project_id`."
  default     = ""
}

variable "min_replicas" {
  type        = number
  description = "Minimum number of instances in the autoscaler."
  default     = 2
}

variable "max_replicas" {
  type        = number
  description = "Maximum number of instances in the autoscaler."
  default     = 6
}

variable "scale_out_cpu_target" {
  type        = number
  description = "Target CPU utilisation (0.0–1.0) that the autoscaler attempts to maintain."
  default     = 0.7
}

variable "registry_port" {
  type        = number
  description = "Port on which the Docker Registry mirror listens on each instance."
  default     = 5000
}

variable "boot_disk_size_gb" {
  type        = number
  description = "Size of the boot persistent disk in GiB."
  default     = 50
}

variable "boot_disk_type" {
  type        = string
  description = "Persistent disk type for the boot disk."
  default     = "pd-ssd"
}

variable "service_account_email" {
  type        = string
  description = "Service account email attached to MIG instances. Defaults to the Compute Engine default service account when empty."
  default     = ""
}

variable "dns_managed_zone" {
  type        = string
  description = "Name of an existing Cloud DNS managed zone in which a DNS A record is created."
}

variable "dns_name" {
  type        = string
  description = "DNS record name including trailing dot (e.g. `mirror.example.com.`). Must be within the managed zone."
}

variable "tags" {
  type        = list(string)
  description = "Network tags applied to MIG instances for firewall rule targeting."
  default     = ["docker-mirror"]
}

variable "labels" {
  type        = map(string)
  description = "Labels applied to all resources."
  default     = {}
}
