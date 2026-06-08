# ubuntu-docker-mirror — AWS Module

Terraform module that deploys the **ubuntu-docker-mirror** image on AWS as a horizontally scalable, highly available service.

## Architecture

```
Internet
  │
  ▼
Application Load Balancer  (public subnets, multi-AZ)
  │  HTTP :80 → HTTPS :443 redirect (when ACM cert supplied)
  ▼
Target Group  :5000
  │
  ├── EC2 instance  AZ-a  (private subnet)
  ├── EC2 instance  AZ-b  (private subnet)
  └── EC2 instance  AZ-n  ...
        ↑ Auto Scaling Group
        │  scale-out: CPU ≥ 70 %  →  +1 instance
        │  scale-in:  CPU ≤ 30 %  →  -1 instance
        │
Route 53 alias  →  ALB DNS name
```

Each EC2 instance runs the ubuntu-docker-mirror Packer image:

- Docker Registry v2 pull-through cache on port 5000
- HCP Terraform agent pre-cached and available via systemd

## Usage

```hcl
module "docker_mirror" {
  source = "./terraform/aws"

  name               = "docker-mirror"
  vpc_id             = "vpc-0abc123"
  public_subnet_ids  = ["subnet-pub-a", "subnet-pub-b"]
  private_subnet_ids = ["subnet-priv-a", "subnet-priv-b"]
  route53_zone_id    = "Z1234567890"
  dns_name           = "mirror.example.com"
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| aws | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| name | Base name prefix applied to all resources | `string` | `"ubuntu-docker-mirror"` | no |
| ami\_name\_filter | Wildcard filter to locate the Packer-built AMI | `string` | `"ubuntu-docker-mirror-*"` | no |
| ami\_owners | AWS account IDs that own the AMI | `list(string)` | `["self"]` | no |
| vpc\_id | ID of the target VPC | `string` | — | **yes** |
| public\_subnet\_ids | Public subnet IDs for the ALB (≥ 2, multi-AZ) | `list(string)` | — | **yes** |
| private\_subnet\_ids | Private subnet IDs for the ASG instances (≥ 2, multi-AZ) | `list(string)` | — | **yes** |
| instance\_type | EC2 instance type | `string` | `"t3.medium"` | no |
| min\_size | ASG minimum instance count | `number` | `2` | no |
| max\_size | ASG maximum instance count | `number` | `6` | no |
| desired\_capacity | ASG desired instance count (defaults to min\_size) | `number` | `null` | no |
| health\_check\_path | ALB health-check HTTP path | `string` | `"/"` | no |
| registry\_port | Docker Registry mirror port | `number` | `5000` | no |
| scale\_out\_cpu\_threshold | CPU % that triggers scale-out | `number` | `70` | no |
| scale\_in\_cpu\_threshold | CPU % that triggers scale-in | `number` | `30` | no |
| route53\_zone\_id | Route 53 hosted zone ID | `string` | — | **yes** |
| dns\_name | DNS record name (e.g. `mirror.example.com`) | `string` | — | **yes** |
| certificate\_arn | ACM certificate ARN for HTTPS listener | `string` | `""` | no |
| root\_volume\_size\_gb | Root EBS volume size in GiB | `number` | `50` | no |
| key\_name | EC2 key pair name for SSH | `string` | `""` | no |
| tags | Additional resource tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| alb\_dns\_name | DNS name of the Application Load Balancer |
| alb\_arn | ARN of the Application Load Balancer |
| alb\_zone\_id | Canonical hosted zone ID of the ALB |
| asg\_name | Name of the Auto Scaling Group |
| launch\_template\_id | ID of the EC2 Launch Template |
| registry\_url | Full URL of the Docker Registry mirror |
| security\_group\_alb\_id | ID of the ALB security group |
| security\_group\_instances\_id | ID of the instances security group |

## Prerequisites

### Packer image

Build the `ubuntu-docker-mirror` AMI for your target AWS region before applying this module:

```bash
cd tfe-local-mirror-aws   # or ubuntu-docker-mirror-aws once available
packer init .
packer build -var "region=us-east-1" .
```

The module looks up the most-recent AMI matching `ami_name_filter` in the account specified by `ami_owners` (defaults to `"self"`).

### Networking

The module expects an existing VPC with:

- At least two **public subnets** (different AZs) for the ALB
- At least two **private subnets** (different AZs) for the EC2 instances
- A NAT Gateway or VPC endpoint so instances can reach Docker Hub

### DNS

An existing Route 53 public or private hosted zone is required. Supply its `zone_id` and the desired `dns_name`.

## Examples

See [`examples/basic`](./examples/basic) for a complete working example.

## Tests

Native Terraform tests live in [`tests/`](./tests/). Run them with:

```bash
cd terraform/aws
terraform test
```

## Security notes

- IMDSv2 is enforced on all instances (hop limit = 1)
- EBS volumes are encrypted at rest
- SSM Session Manager is enabled via `AmazonSSMManagedInstanceCore` — SSH key is optional
- ALB → instances traffic is restricted to the registry port only
