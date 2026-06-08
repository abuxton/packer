terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

module "docker_mirror" {
  source = "../../"

  name                    = "docker-mirror-example"
  resource_group_name     = "rg-docker-mirror-example"
  location                = var.location
  image_resource_group    = var.image_resource_group
  subnet_id               = var.subnet_id
  admin_ssh_public_key    = var.admin_ssh_public_key

  vm_sku         = "Standard_D2s_v5"
  instance_count = 2
  min_count      = 2
  max_count      = 4

  dns_zone_name           = var.dns_zone_name
  dns_zone_resource_group = var.dns_zone_resource_group
  dns_record_name         = "mirror"

  tags = { Environment = "example" }
}
