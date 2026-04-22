variable "subscription_id" {
  type        = string
  description = "Azure subscription ID. Can also be set via ARM_SUBSCRIPTION_ID environment variable."
}

variable "resource_group" {
  type        = string
  description = "Existing Azure resource group where the managed image will be stored. Must already exist before running packer build."
}

variable "location" {
  type        = string
  description = "Azure region for the build VM and output image (e.g. 'eastus', 'westeurope')."
  default     = "eastus"
}

variable "vm_size" {
  type        = string
  description = "Azure VM size for the build instance. Standard_D4s_v3 (4 vCPU / 16 GB) recommended for pulling the TFE image."
  default     = "Standard_D4s_v3"
}

variable "image_name" {
  type        = string
  description = "Base name of the resulting managed image. A timestamp is appended automatically."
  default     = "tfe-local-mirror"
}

variable "disk_size" {
  type        = number
  description = "OS disk size in GB. 100 GB recommended to accommodate TFE image layers and registry storage."
  default     = 100
}

variable "tfe_version" {
  type        = string
  description = "Terraform Enterprise image tag to pull (e.g. 'v202506-1' or '1.2.1'). See https://developer.hashicorp.com/terraform/enterprise/releases"
  default     = "1.2.1"
}

variable "tfe_license_file" {
  type        = string
  description = "Local path to the HashiCorp Terraform Enterprise license file (.hclic). Used only during the Packer build to authenticate to images.releases.hashicorp.com. Never committed to source control. './files/terraform.hclic' is the recommended location (git-ignored)."
  default     = "./files/terraform.hclic"
}
