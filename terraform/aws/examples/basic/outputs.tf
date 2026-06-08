output "registry_url" {
  description = "URL of the Docker Registry mirror."
  value       = module.docker_mirror.registry_url
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer."
  value       = module.docker_mirror.alb_dns_name
}

output "asg_name" {
  description = "Name of the Auto Scaling Group."
  value       = module.docker_mirror.asg_name
}
