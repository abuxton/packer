variable "vcenter_server" {
  type        = string
  description = "Hostname or IP of the vCenter Server."
}

variable "vcenter_username" {
  type        = string
  description = "vCenter username (e.g. 'administrator@vsphere.local')."
}

variable "vcenter_password" {
  type        = string
  sensitive   = true
  description = "vCenter password. Mark as sensitive — never commit a value to source control."
}

variable "insecure_connection" {
  type        = bool
  description = "Allow insecure (self-signed certificate) connections to vCenter. Set true for lab environments."
  default     = false
}

variable "datacenter" {
  type        = string
  description = "vSphere datacenter name."
  default     = ""
}

variable "cluster" {
  type        = string
  description = "vSphere cluster or ESXi host where the build VM will run."
}

variable "datastore" {
  type        = string
  description = "vSphere datastore for the build VM disks."
}

variable "network" {
  type        = string
  description = "vSphere port group / network name to attach to the build VM."
}

variable "folder" {
  type        = string
  description = "vSphere VM folder path for the build VM and resulting template."
  default     = ""
}

variable "vm_name" {
  type        = string
  description = "Base name of the resulting vSphere VM template. A timestamp is appended automatically."
  default     = "tfe-local-mirror"
}

variable "cpus" {
  type        = number
  description = "Number of vCPUs for the build VM. 4 recommended."
  default     = 4
}

variable "ram_mb" {
  type        = number
  description = "RAM in MB for the build VM. 16384 (16 GB) recommended for pulling the TFE image."
  default     = 16384
}

variable "disk_size" {
  type        = number
  description = "Root disk size in GB. 100 GB recommended to accommodate TFE image layers and registry storage."
  default     = 100
}

variable "iso_url" {
  type        = string
  description = "URL or datastore path to the Ubuntu 24.04 LTS server ISO. Example: 'https://releases.ubuntu.com/24.04/ubuntu-24.04.2-live-server-amd64.iso'"
  default     = "https://releases.ubuntu.com/24.04/ubuntu-24.04.4-live-server-amd64.iso"
}

variable "iso_checksum" {
  type        = string
  description = "Checksum for the ISO. Use 'file:https://releases.ubuntu.com/24.04/SHA256SUMS' to fetch automatically, or provide 'sha256:<hash>' directly."
  default     = "file:https://releases.ubuntu.com/24.04/SHA256SUMS"
}

variable "ssh_password" {
  type        = string
  sensitive   = true
  description = "Password for the 'packer' build user created by autoinstall. Must match the hashed value in http/user-data. This password is locked on the template after provisioning completes."
  default     = "packer"
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
