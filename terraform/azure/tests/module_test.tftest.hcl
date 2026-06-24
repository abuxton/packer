# Tests for the ubuntu-docker-mirror Azure module
#
# Run with:  terraform test  (Terraform >= 1.6)
#
# These tests validate plan-time behaviour without requiring real Azure credentials.

variables {
  resource_group_name     = "rg-test-mirror"
  location                = "eastus"
  image_resource_group    = "rg-packer-images"
  subnet_id               = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/subnet-test"
  admin_ssh_public_key    = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC test@test"
  dns_zone_name           = "test.example.com"
  dns_zone_resource_group = "rg-dns"
}

# ── Validate default variable values ───────────────────────────────────────────
run "defaults_are_sane" {
  command = plan

  assert {
    condition     = var.vm_sku == "Standard_D2s_v5"
    error_message = "Default vm_sku should be Standard_D2s_v5"
  }

  assert {
    condition     = var.min_count == 2
    error_message = "Default min_count should be 2"
  }

  assert {
    condition     = var.max_count == 6
    error_message = "Default max_count should be 6"
  }

  assert {
    condition     = var.registry_port == 5000
    error_message = "Default registry_port should be 5000"
  }

  assert {
    condition     = var.admin_username == "azureuser"
    error_message = "Default admin_username should be azureuser"
  }
}

# ── Validate DNS record name default ───────────────────────────────────────────
run "dns_record_name_default" {
  command = plan

  assert {
    condition     = var.dns_record_name == "mirror"
    error_message = "Default dns_record_name should be mirror"
  }
}

# ── Validate autoscale thresholds ──────────────────────────────────────────────
run "autoscale_thresholds_default" {
  command = plan

  assert {
    condition     = var.scale_out_cpu_threshold == 70
    error_message = "Default scale_out_cpu_threshold should be 70"
  }

  assert {
    condition     = var.scale_in_cpu_threshold == 30
    error_message = "Default scale_in_cpu_threshold should be 30"
  }
}

# ── Validate resource group is created ─────────────────────────────────────────
run "resource_group_created" {
  command = plan

  assert {
    condition     = azurerm_resource_group.mirror.name == var.resource_group_name
    error_message = "Resource group name should match var.resource_group_name"
  }

  assert {
    condition     = azurerm_resource_group.mirror.location == var.location
    error_message = "Resource group location should match var.location"
  }
}

# ── Validate VMSS uses correct SKU ─────────────────────────────────────────────
run "vmss_sku_matches_variable" {
  command = plan

  variables {
    vm_sku = "Standard_D4s_v5"
  }

  assert {
    condition     = azurerm_linux_virtual_machine_scale_set.mirror.sku == "Standard_D4s_v5"
    error_message = "VMSS SKU should match var.vm_sku"
  }
}
