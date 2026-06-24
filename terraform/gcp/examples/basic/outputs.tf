output "registry_url" {
  description = "URL of the Docker Registry mirror."
  value       = module.docker_mirror.registry_url
}

output "load_balancer_ip" {
  description = "Global anycast IP of the HTTP Load Balancer."
  value       = module.docker_mirror.load_balancer_ip
}

output "instance_group_manager_id" {
  description = "Self-link of the Managed Instance Group manager."
  value       = module.docker_mirror.instance_group_manager_id
}
