variable "aws_region" {
  type        = string
  description = "AWS region in which to deploy the example."
  default     = "us-east-1"
}

variable "route53_zone_id" {
  type        = string
  description = "Route 53 hosted zone ID for DNS record creation."
}

variable "domain_name" {
  type        = string
  description = "Parent domain name (e.g. example.com). A `mirror.` sub-domain is created."
}
