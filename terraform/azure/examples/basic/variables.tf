variable "subscription_id" {
  type        = string
  description = "Azure subscription ID."
}

variable "location" {
  type        = string
  description = "Azure region for example resources."
  default     = "eastus"
}

variable "image_resource_group" {
  type        = string
  description = "Resource group containing the Packer-built ubuntu-docker-mirror Managed Image."
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID for VMSS instances."
}

variable "admin_ssh_public_key" {
  type        = string
  description = "SSH public key content for the administrator account."
}

variable "dns_zone_name" {
  type        = string
  description = "Existing Azure DNS zone name."
}

variable "dns_zone_resource_group" {
  type        = string
  description = "Resource group containing the DNS zone."
}
