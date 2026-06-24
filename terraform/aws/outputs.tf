output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer."
  value       = aws_lb.mirror.dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer."
  value       = aws_lb.mirror.arn
}

output "alb_zone_id" {
  description = "Canonical hosted zone ID of the ALB (for Route 53 alias records)."
  value       = aws_lb.mirror.zone_id
}

output "asg_name" {
  description = "Name of the Auto Scaling Group."
  value       = aws_autoscaling_group.mirror.name
}

output "launch_template_id" {
  description = "ID of the EC2 Launch Template."
  value       = aws_launch_template.mirror.id
}

output "registry_url" {
  description = "URL of the Docker Registry mirror (uses DNS alias when set, otherwise the ALB DNS name)."
  value       = "http://${aws_route53_record.mirror.fqdn}:${var.registry_port}"
}

output "security_group_alb_id" {
  description = "ID of the ALB security group."
  value       = aws_security_group.alb.id
}

output "security_group_instances_id" {
  description = "ID of the instances security group."
  value       = aws_security_group.instances.id
}
