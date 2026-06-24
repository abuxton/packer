output "registry_url" {
  description = "URL of the Docker Registry mirror."
  value       = module.docker_mirror.registry_url
}

output "load_balancer_public_ip" {
  description = "Public IP address of the Load Balancer."
  value       = module.docker_mirror.load_balancer_public_ip
}

output "vmss_id" {
  description = "Resource ID of the VMSS."
  value       = module.docker_mirror.vmss_id
}
