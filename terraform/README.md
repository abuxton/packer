# Terraform Modules

This directory contains three Terraform modules that deploy the **ubuntu-docker-mirror** Packer image as a horizontally scalable, highly available Docker Registry pull-through cache service across the three major cloud platforms.

## Modules

| Module | Cloud | Scaling mechanism | DNS |
|--------|-------|-------------------|-----|
| [`aws/`](./aws/) | Amazon Web Services | EC2 Auto Scaling Group + ALB | Route 53 alias record |
| [`azure/`](./azure/) | Microsoft Azure | Virtual Machine Scale Set | Azure DNS A record |
| [`gcp/`](./gcp/) | Google Cloud Platform | Regional Managed Instance Group | Cloud DNS A record |

Each module is self-contained with its own `README.md`, `examples/`, and `tests/` directories.

## Common design principles

- **Horizontal scaling with redundancy** — all modules spread instances across multiple availability zones or failure domains and expose a single load-balanced endpoint.
- **Auto-scaling** — CPU-based autoscale policies grow or shrink the fleet automatically.
- **DNS-fronted endpoint** — a DNS record points to the load balancer so consumers use a stable name regardless of scaling events.
- **Secure defaults** — encrypted disks, no unnecessary public access to instances, and IMDSv2 / Shielded VM where applicable.

## Prerequisites

Build the ubuntu-docker-mirror image for your target platform(s) using the Packer templates in this repository before applying any Terraform module:

```bash
# GCP
cd ubuntu-docker-mirror
packer build -var "project_id=<project>" .

# AWS (uses tfe-local-mirror-aws pattern; adapt for a docker-mirror-only AMI)
cd tfe-local-mirror-aws
packer build -var "region=us-east-1" .

# Azure (uses tfe-local-mirror-azure pattern)
cd tfe-local-mirror-azure
packer build -var "subscription_id=<sub-id>" -var "resource_group=rg-images" .
```

## Running tests

Each module uses the native Terraform test framework (Terraform ≥ 1.6):

```bash
cd terraform/aws   && terraform test
cd terraform/azure && terraform test
cd terraform/gcp   && terraform test
```

## Module quick-start

### AWS

```hcl
module "docker_mirror_aws" {
  source = "./terraform/aws"

  vpc_id             = "vpc-0abc123"
  public_subnet_ids  = ["subnet-pub-a", "subnet-pub-b"]
  private_subnet_ids = ["subnet-priv-a", "subnet-priv-b"]
  route53_zone_id    = "Z1234567890"
  dns_name           = "mirror.example.com"
}
```

### Azure

```hcl
module "docker_mirror_azure" {
  source = "./terraform/azure"

  resource_group_name     = "rg-docker-mirror"
  image_resource_group    = "rg-packer-images"
  subnet_id               = azurerm_subnet.main.id
  admin_ssh_public_key    = file("~/.ssh/id_rsa.pub")
  dns_zone_name           = "example.com"
  dns_zone_resource_group = "rg-dns"
}
```

### GCP

```hcl
module "docker_mirror_gcp" {
  source = "./terraform/gcp"

  project_id       = "my-gcp-project"
  subnetwork       = "projects/my-gcp-project/regions/us-central1/subnetworks/default"
  dns_managed_zone = "example-zone"
  dns_name         = "mirror.example.com."
}
```
