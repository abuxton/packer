variable "region" {
  type        = string
  description = "AWS region in which to build and register the AMI."
  default     = "us-east-1"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for the build instance. m5.xlarge (4 vCPU / 16 GB) recommended for pulling the TFE image."
  default     = "m5.xlarge"
}

variable "ami_name" {
  type        = string
  description = "Base name of the resulting AMI. A timestamp is appended automatically."
  default     = "tfe-local-mirror"
}

variable "disk_size" {
  type        = number
  description = "Root EBS volume size in GB. 100 GB recommended to accommodate TFE image layers and registry storage."
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
