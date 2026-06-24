output "load_balancer_public_ip" {
  description = "Public IP address of the Azure Load Balancer."
  value       = azurerm_public_ip.lb.ip_address
}

output "load_balancer_id" {
  description = "Resource ID of the Azure Load Balancer."
  value       = azurerm_lb.mirror.id
}

output "vmss_id" {
  description = "Resource ID of the Virtual Machine Scale Set."
  value       = azurerm_linux_virtual_machine_scale_set.mirror.id
}

output "vmss_identity_principal_id" {
  description = "Principal ID of the VMSS system-assigned managed identity."
  value       = azurerm_linux_virtual_machine_scale_set.mirror.identity[0].principal_id
}

output "resource_group_name" {
  description = "Name of the resource group."
  value       = azurerm_resource_group.mirror.name
}

output "dns_fqdn" {
  description = "Fully qualified domain name of the DNS A record."
  value       = "${azurerm_dns_a_record.mirror.name}.${var.dns_zone_name}"
}

output "registry_url" {
  description = "URL of the Docker Registry mirror."
  value       = "http://${azurerm_dns_a_record.mirror.name}.${var.dns_zone_name}:${var.registry_port}"
}
