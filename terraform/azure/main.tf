locals {
  name = var.name

  common_tags = merge(
    { Module = "ubuntu-docker-mirror-azure", ManagedBy = "terraform" },
    var.tags
  )
}

# ── Image lookup ────────────────────────────────────────────────────────────────
data "azurerm_images" "mirror" {
  resource_group_name = var.image_resource_group

  tags_filter = {
    Packer = "true"
  }
}

locals {
  # Pick the most recently created image whose name starts with the prefix.
  mirror_images = [
    for img in data.azurerm_images.mirror.images :
    img if startswith(img.name, var.image_name_prefix)
  ]
  mirror_image_id = local.mirror_images[length(local.mirror_images) - 1].id
}

# ── Resource group ──────────────────────────────────────────────────────────────
resource "azurerm_resource_group" "mirror" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# ── Public IP for load balancer ─────────────────────────────────────────────────
resource "azurerm_public_ip" "lb" {
  name                = "${local.name}-lb"
  resource_group_name = azurerm_resource_group.mirror.name
  location            = azurerm_resource_group.mirror.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

# ── Network Security Group ──────────────────────────────────────────────────────
resource "azurerm_network_security_group" "mirror" {
  name                = "${local.name}-nsg"
  resource_group_name = azurerm_resource_group.mirror.name
  location            = azurerm_resource_group.mirror.location
  tags                = local.common_tags

  security_rule {
    name                       = "AllowRegistryFromLB"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = tostring(var.registry_port)
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
    description                = "Registry traffic from Azure Load Balancer"
  }

  security_rule {
    name                       = "AllowAzureLoadBalancerProbe"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = tostring(var.registry_port)
    source_address_prefix      = "168.63.129.16"
    destination_address_prefix = "*"
    description                = "Azure health probe source"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Deny all other inbound traffic"
  }
}

# ── Load Balancer ───────────────────────────────────────────────────────────────
resource "azurerm_lb" "mirror" {
  name                = "${local.name}-lb"
  resource_group_name = azurerm_resource_group.mirror.name
  location            = azurerm_resource_group.mirror.location
  sku                 = "Standard"
  tags                = local.common_tags

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

resource "azurerm_lb_backend_address_pool" "mirror" {
  name            = "${local.name}-pool"
  loadbalancer_id = azurerm_lb.mirror.id
}

resource "azurerm_lb_probe" "registry" {
  name                = "${local.name}-registry-probe"
  loadbalancer_id     = azurerm_lb.mirror.id
  protocol            = "Http"
  port                = var.registry_port
  request_path        = "/"
  interval_in_seconds = 15
  number_of_probes    = 3
}

resource "azurerm_lb_rule" "registry" {
  name                           = "${local.name}-registry-rule"
  loadbalancer_id                = azurerm_lb.mirror.id
  frontend_ip_configuration_name = "PublicIPAddress"
  protocol                       = "Tcp"
  frontend_port                  = var.registry_port
  backend_port                   = var.registry_port
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.mirror.id]
  probe_id                       = azurerm_lb_probe.registry.id
  load_distribution              = "SourceIPProtocol"
  idle_timeout_in_minutes        = 4
  enable_tcp_reset               = true
}

# ── Virtual Machine Scale Set ───────────────────────────────────────────────────
resource "azurerm_linux_virtual_machine_scale_set" "mirror" {
  name                = local.name
  resource_group_name = azurerm_resource_group.mirror.name
  location            = azurerm_resource_group.mirror.location
  sku                 = var.vm_sku
  instances           = var.instance_count
  upgrade_mode        = "Rolling"

  admin_username = var.admin_username

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  source_image_id = local.mirror_image_id

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.os_disk_size_gb
  }

  network_interface {
    name    = "${local.name}-nic"
    primary = true

    network_security_group_id = azurerm_network_security_group.mirror.id

    ip_configuration {
      name                                   = "primary"
      primary                                = true
      subnet_id                              = var.subnet_id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.mirror.id]
    }
  }

  rolling_upgrade_policy {
    max_batch_instance_percent              = 25
    max_unhealthy_instance_percent          = 25
    max_unhealthy_upgraded_instance_percent = 5
    pause_time_between_batches              = "PT2M"
  }

  health_probe_id = azurerm_lb_probe.registry.id

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags

  lifecycle {
    ignore_changes = [instances]
  }
}

# ── Autoscale settings ──────────────────────────────────────────────────────────
resource "azurerm_monitor_autoscale_setting" "mirror" {
  name                = "${local.name}-autoscale"
  resource_group_name = azurerm_resource_group.mirror.name
  location            = azurerm_resource_group.mirror.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.mirror.id
  tags                = local.common_tags

  profile {
    name = "default"

    capacity {
      default = var.instance_count
      minimum = var.min_count
      maximum = var.max_count
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.mirror.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThanOrEqual"
        threshold          = var.scale_out_cpu_threshold
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT2M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.mirror.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThanOrEqual"
        threshold          = var.scale_in_cpu_threshold
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }
    }
  }
}

# ── DNS record ──────────────────────────────────────────────────────────────────
resource "azurerm_dns_a_record" "mirror" {
  name                = var.dns_record_name
  zone_name           = var.dns_zone_name
  resource_group_name = var.dns_zone_resource_group
  ttl                 = 300
  records             = [azurerm_public_ip.lb.ip_address]
  tags                = local.common_tags
}
