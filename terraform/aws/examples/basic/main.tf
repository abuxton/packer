terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ── Networking (simplified – use an existing VPC in real deployments) ───────────
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "docker-mirror-example"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.10.0/24", "10.0.11.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = { Example = "ubuntu-docker-mirror" }
}

module "docker_mirror" {
  source = "../../"

  name               = "docker-mirror-example"
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnets
  private_subnet_ids = module.vpc.private_subnets

  instance_type    = "t3.medium"
  min_size         = 2
  max_size         = 4
  desired_capacity = 2

  route53_zone_id = var.route53_zone_id
  dns_name        = "mirror.${var.domain_name}"

  tags = { Environment = "example" }
}
