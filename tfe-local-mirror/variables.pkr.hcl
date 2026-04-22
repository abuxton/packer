variable "project_id" {
  type        = string
  description = "The GCP project ID where the image will be built."
}

variable "zone" {
  type        = string
  description = "The GCP zone where the build instance will run."
  default     = "us-central1-a"
}

variable "machine_type" {
  type        = string
  description = "The GCP machine type for the build instance. e2-standard-4 recommended (TFE image is large)."
  default     = "e2-standard-4"
}

variable "image_name" {
  type        = string
  description = "Base name of the resulting Compute Engine image. A timestamp is appended automatically."
  default     = "tfe-local-mirror"
}

variable "image_family" {
  type        = string
  description = "The image family assigned to the resulting image."
  default     = "tfe-local-mirror"
}

variable "disk_size" {
  type        = number
  description = "Boot disk size in GB. 100 GB recommended to accommodate the TFE image layers and registry storage."
  default     = 100
}

variable "tfe_version" {
  type        = string
  description = "Terraform Enterprise image tag to pull (e.g. 'v202506-1'). See https://developer.hashicorp.com/terraform/enterprise/releases"
}

variable "tfe_license_file" {
  type        = string
  description = "Local path to the HashiCorp Terraform Enterprise license file (.hclic). Used only during the Packer build to authenticate to images.releases.hashicorp.com. Never committed to source control."
  default     = "./files/terraform.hclic"
}
