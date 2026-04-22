# tfe-local-mirror-aws

Packer template that builds an AWS AMI (Ubuntu 24.04 LTS) with Terraform Enterprise
pre-loaded into a local Docker registry. The resulting AMI is used for air-gapped or
offline TFE deployments where pulling the image at runtime is not permitted.

**Reference:** <https://developer.hashicorp.com/terraform/enterprise/deploy/docker>

---

## Prerequisites

- [Packer](https://developer.hashicorp.com/packer/install) ≥ 1.10
- AWS credentials configured (any standard method: `aws configure`, `AWS_*` env vars, IAM instance profile)
- IAM permissions: `ec2:RunInstances`, `ec2:DescribeImages`, `ec2:CreateImage`, `ec2:TerminateInstances`, `ec2:CreateTags`, `ec2:DescribeSubnets`, `ec2:DescribeSecurityGroups`
- A valid Terraform Enterprise license file (`.hclic`) — **never commit this file**

---

## Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `region` | | `us-east-1` | AWS region for the build and AMI |
| `instance_type` | | `t3.xlarge` | EC2 instance type (≥4 vCPU, ≥16 GB recommended) |
| `ami_name` | | `tfe-local-mirror` | Base name for the resulting AMI (timestamp appended) |
| `disk_size` | | `100` | Root EBS volume size in GB |
| `tfe_version` | | `1.2.1` | TFE image tag — see [TFE releases](https://developer.hashicorp.com/terraform/enterprise/releases) |
| `tfe_license_file` | | `./files/terraform.hclic` | Local path to your `.hclic` license file |

---

## Quick Start

1. Copy your license file into the template directory (git-ignored):

   ```bash
   cp /path/to/your/terraform.hclic tfe-local-mirror-aws/files/terraform.hclic
   ```

2. Initialise plugins:

   ```bash
   packer init tfe-local-mirror-aws
   ```

3. Build the AMI:

   ```bash
   packer build tfe-local-mirror-aws
   ```

   Override variables as needed:

   ```bash
   packer build \
     -var "region=eu-west-1" \
     -var "tfe_version=1.3.0" \
     -var "tfe_license_file=/absolute/path/terraform.hclic" \
     tfe-local-mirror-aws
   ```

---

## Security Notes

- The license file is uploaded to `/tmp/tfe.hclic` on the build instance, used to authenticate to `images.releases.hashicorp.com`, and **deleted** before the AMI is captured.
- `*.hclic` is listed in `.gitignore` — do not force-add it.
- The `files/` directory contains only a `.gitkeep`; the actual license file is git-ignored.
