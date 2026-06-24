variable "name" {
  type        = string
  description = "Base name prefix applied to all resources created by this module."
  default     = "ubuntu-docker-mirror"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the Azure resource group in which all resources are created."
}

variable "location" {
  type        = string
  description = "Azure region for all resources (e.g. `eastus`, `westeurope`)."
  default     = "eastus"
}

variable "image_resource_group" {
  type        = string
  description = "Resource group that contains the ubuntu-docker-mirror Managed Image built by Packer."
}

variable "image_name_prefix" {
  type        = string
  description = "Prefix used to find the most-recent Packer-built Managed Image. The module selects the image whose name starts with this value."
  default     = "ubuntu-docker-mirror"
}

variable "subnet_id" {
  type        = string
  description = "ID of the subnet in which VMSS instances are placed."
}

variable "vm_sku" {
  type        = string
  description = "Azure VM SKU for scale set instances."
  default     = "Standard_D2s_v5"
}

variable "instance_count" {
  type        = number
  description = "Initial number of VMSS instances."
  default     = 2
}

variable "min_count" {
  type        = number
  description = "Minimum number of VMSS instances (autoscale lower bound)."
  default     = 2
}

variable "max_count" {
  type        = number
  description = "Maximum number of VMSS instances (autoscale upper bound)."
  default     = 6
}

variable "scale_out_cpu_threshold" {
  type        = number
  description = "Average CPU utilisation percentage that triggers a scale-out event."
  default     = 70
}

variable "scale_in_cpu_threshold" {
  type        = number
  description = "Average CPU utilisation percentage that triggers a scale-in event."
  default     = 30
}

variable "registry_port" {
  type        = number
  description = "Port on which the Docker Registry mirror listens on each instance."
  default     = 5000
}

variable "admin_username" {
  type        = string
  description = "Administrator username for VMSS instances."
  default     = "azureuser"
}

variable "admin_ssh_public_key" {
  type        = string
  description = "SSH public key content added to the administrator account."
}

variable "os_disk_size_gb" {
  type        = number
  description = "OS disk size in GiB."
  default     = 50
}

variable "dns_zone_name" {
  type        = string
  description = "Name of an existing Azure DNS zone (e.g. `example.com`) in which a DNS record is created."
}

variable "dns_zone_resource_group" {
  type        = string
  description = "Resource group that contains the Azure DNS zone."
}

variable "dns_record_name" {
  type        = string
  description = "Name of the DNS A record created in the zone (e.g. `mirror`)."
  default     = "mirror"
}

variable "tags" {
  type        = map(string)
  description = "Additional resource tags merged with module-managed tags."
  default     = {}
}
