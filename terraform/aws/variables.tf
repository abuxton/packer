variable "name" {
  type        = string
  description = "Base name prefix applied to all resources created by this module."
  default     = "ubuntu-docker-mirror"
}

variable "ami_name_filter" {
  type        = string
  description = "Name filter used to locate the ubuntu-docker-mirror AMI built by Packer. Supports wildcards."
  default     = "ubuntu-docker-mirror-*"
}

variable "ami_owners" {
  type        = list(string)
  description = "List of AWS account IDs that own the AMI identified by `ami_name_filter`. Defaults to the caller's own account."
  default     = ["self"]
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC in which all resources are created."
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "List of public subnet IDs (minimum 2, spread across AZs) used for the Application Load Balancer."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs (minimum 2, spread across AZs) used for the Auto Scaling Group instances."
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for the Auto Scaling Group."
  default     = "t3.medium"
}

variable "min_size" {
  type        = number
  description = "Minimum number of instances in the Auto Scaling Group."
  default     = 2
}

variable "max_size" {
  type        = number
  description = "Maximum number of instances in the Auto Scaling Group."
  default     = 6
}

variable "desired_capacity" {
  type        = number
  description = "Desired number of instances in the Auto Scaling Group. Defaults to `min_size` when null."
  default     = null
}

variable "health_check_path" {
  type        = string
  description = "HTTP path used by the ALB target-group health check."
  default     = "/"
}

variable "registry_port" {
  type        = number
  description = "Port on which the Docker Registry mirror listens on each instance."
  default     = 5000
}

variable "scale_out_cpu_threshold" {
  type        = number
  description = "Average CPU utilisation percentage that triggers a scale-out event."
  default     = 70
}

variable "scale_in_cpu_threshold" {
  type        = number
  description = "Average CPU utilisation percentage that triggers a scale-in event."
  default     = 30
}

variable "route53_zone_id" {
  type        = string
  description = "Route 53 hosted zone ID in which the DNS alias record is created."
}

variable "dns_name" {
  type        = string
  description = "DNS record name (e.g. `mirror.example.com`) created in the Route 53 hosted zone."
}

variable "certificate_arn" {
  type        = string
  description = "ARN of an ACM certificate to attach to the HTTPS listener. When empty the module creates an HTTP-only listener on port 80."
  default     = ""
}

variable "root_volume_size_gb" {
  type        = number
  description = "Size of the root EBS volume (GiB) attached to each instance."
  default     = 50
}

variable "key_name" {
  type        = string
  description = "Name of an existing EC2 key pair for SSH access. Leave empty to disable SSH."
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Additional resource tags merged with module-managed tags."
  default     = {}
}
