# ubuntu-docker-mirror — GCP Module

Terraform module that deploys the **ubuntu-docker-mirror** image on Google Cloud Platform as a horizontally scalable, highly available service using a **Regional Managed Instance Group (MIG)** and a **Cloud HTTP Load Balancer**.

## Architecture

```
Internet
  │
  ▼
Cloud Global HTTP Load Balancer  (global anycast IP)
  │  HTTP :80  →  backend :5000
  ▼
Backend Service  (named port "registry")
  │
  ├── MIG instance  zone-a  (region-spread)
  ├── MIG instance  zone-b
  └── MIG instance  zone-n  ...
        ↑ Cloud Autoscaler
        │  target CPU utilisation: 70 %
        │  min: 2  /  max: 6
        │
Cloud DNS A record  →  Load Balancer anycast IP
```

Each MIG instance runs the ubuntu-docker-mirror Packer image:

- Docker Registry v2 pull-through cache on port 5000
- HCP Terraform agent pre-cached and available via systemd

## Usage

```hcl
module "docker_mirror" {
  source = "./terraform/gcp"

  project_id       = "my-gcp-project"
  region           = "us-central1"
  subnetwork       = "projects/my-gcp-project/regions/us-central1/subnetworks/default"
  dns_managed_zone = "example-zone"
  dns_name         = "mirror.example.com."
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| google | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| google | >= 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project\_id | GCP project ID | `string` | — | **yes** |
| name | Base name prefix for all resources | `string` | `"ubuntu-docker-mirror"` | no |
| region | GCP region | `string` | `"us-central1"` | no |
| image\_family | Compute Engine image family to resolve | `string` | `"ubuntu-docker-mirror"` | no |
| image\_project | GCP project owning the image family | `string` | `""` (uses project\_id) | no |
| machine\_type | Compute Engine machine type | `string` | `"e2-standard-2"` | no |
| subnetwork | Subnetwork self-link or name for instances | `string` | — | **yes** |
| subnetwork\_project | Project for the subnetwork (shared VPC) | `string` | `""` (uses project\_id) | no |
| min\_replicas | Autoscaler minimum replicas | `number` | `2` | no |
| max\_replicas | Autoscaler maximum replicas | `number` | `6` | no |
| scale\_out\_cpu\_target | Target CPU utilisation for autoscaler (0.0–1.0) | `number` | `0.7` | no |
| registry\_port | Docker Registry mirror port | `number` | `5000` | no |
| boot\_disk\_size\_gb | Boot disk size in GiB | `number` | `50` | no |
| boot\_disk\_type | Boot disk persistent disk type | `string` | `"pd-ssd"` | no |
| service\_account\_email | Service account email for instances | `string` | `""` | no |
| dns\_managed\_zone | Cloud DNS managed zone name | `string` | — | **yes** |
| dns\_name | DNS record name with trailing dot | `string` | — | **yes** |
| tags | Network tags for firewall targeting | `list(string)` | `["docker-mirror"]` | no |
| labels | Labels applied to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| load\_balancer\_ip | Global anycast IP of the HTTP Load Balancer |
| load\_balancer\_ip\_name | Name of the reserved global IP resource |
| instance\_group\_manager\_id | Self-link of the regional MIG manager |
| instance\_group | Self-link of the instance group |
| instance\_template\_id | Self-link of the instance template |
| registry\_url | URL of the Docker Registry mirror |
| dns\_name | DNS record name in the managed zone |

## Prerequisites

### Packer image

Build the `ubuntu-docker-mirror` image for your GCP project before applying this module:

```bash
cd ubuntu-docker-mirror
packer init .
packer build -var "project_id=my-gcp-project" .
```

The module resolves the most-recent image from the `image_family` (default `ubuntu-docker-mirror`).

### Networking

Supply the subnetwork self-link or name. Instances have no external IP — ensure a **Cloud NAT** gateway exists on the VPC for outbound Docker Hub access.

### DNS

Supply an existing Cloud DNS managed zone name and the desired DNS record name (with trailing dot, e.g. `mirror.example.com.`).

### Required APIs

Enable the following GCP APIs:

```bash
gcloud services enable compute.googleapis.com dns.googleapis.com --project=my-gcp-project
```

## Examples

See [`examples/basic`](./examples/basic) for a complete working example.

## Tests

Native Terraform tests live in [`tests/`](./tests/). Run them with:

```bash
cd terraform/gcp
terraform test
```
