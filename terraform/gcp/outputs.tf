output "load_balancer_ip" {
  description = "Global anycast IP address of the HTTP Load Balancer."
  value       = google_compute_global_address.mirror.address
}

output "load_balancer_ip_name" {
  description = "Name of the reserved global IP address resource."
  value       = google_compute_global_address.mirror.name
}

output "instance_group_manager_id" {
  description = "Self-link of the regional Managed Instance Group manager."
  value       = google_compute_region_instance_group_manager.mirror.self_link
}

output "instance_group" {
  description = "Self-link of the instance group (for use as a load balancer backend)."
  value       = google_compute_region_instance_group_manager.mirror.instance_group
}

output "instance_template_id" {
  description = "Self-link of the instance template."
  value       = google_compute_instance_template.mirror.self_link
}

output "registry_url" {
  description = "URL of the Docker Registry mirror via the load balancer."
  value       = "http://${google_compute_global_address.mirror.address}:80"
}

output "dns_name" {
  description = "DNS record name created in the managed zone."
  value       = google_dns_record_set.mirror.name
}
