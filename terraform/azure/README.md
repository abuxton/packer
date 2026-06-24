# ubuntu-docker-mirror — Azure Module

Terraform module that deploys the **ubuntu-docker-mirror** image on Azure as a horizontally scalable, highly available service using a **Virtual Machine Scale Set (VMSS)** and an **Azure Load Balancer**.

## Architecture

```
Internet
  │
  ▼
Azure Standard Load Balancer  (public IP)
  │  TCP :5000
  ▼
Backend Address Pool
  │
  ├── VMSS instance  (zone-redundant)
  ├── VMSS instance
  └── VMSS instance  ...
        ↑ Azure Monitor Autoscale
        │  scale-out: CPU ≥ 70 %  →  +1 instance
        │  scale-in:  CPU ≤ 30 %  →  -1 instance
        │
Azure DNS A record  →  Load Balancer public IP
```

Each VMSS instance runs the ubuntu-docker-mirror Packer image:

- Docker Registry v2 pull-through cache on port 5000
- HCP Terraform agent pre-cached and available via systemd

## Usage

```hcl
module "docker_mirror" {
  source = "./terraform/azure"

  name                    = "docker-mirror"
  resource_group_name     = "rg-docker-mirror"
  location                = "eastus"
  image_resource_group    = "rg-packer-images"
  subnet_id               = azurerm_subnet.main.id
  admin_ssh_public_key    = file("~/.ssh/id_rsa.pub")

  dns_zone_name           = "example.com"
  dns_zone_resource_group = "rg-dns"
  dns_record_name         = "mirror"
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| azurerm | >= 3.100 |

## Providers

| Name | Version |
|------|---------|
| azurerm | >= 3.100 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| name | Base name prefix for all resources | `string` | `"ubuntu-docker-mirror"` | no |
| resource\_group\_name | Name of the resource group to create | `string` | — | **yes** |
| location | Azure region | `string` | `"eastus"` | no |
| image\_resource\_group | Resource group containing the Packer-built Managed Image | `string` | — | **yes** |
| image\_name\_prefix | Prefix filter for the Managed Image name | `string` | `"ubuntu-docker-mirror"` | no |
| subnet\_id | Subnet ID for VMSS instances | `string` | — | **yes** |
| vm\_sku | VM SKU for scale set instances | `string` | `"Standard_D2s_v5"` | no |
| instance\_count | Initial VMSS instance count | `number` | `2` | no |
| min\_count | Autoscale minimum instance count | `number` | `2` | no |
| max\_count | Autoscale maximum instance count | `number` | `6` | no |
| scale\_out\_cpu\_threshold | CPU % triggering scale-out | `number` | `70` | no |
| scale\_in\_cpu\_threshold | CPU % triggering scale-in | `number` | `30` | no |
| registry\_port | Docker Registry mirror port | `number` | `5000` | no |
| admin\_username | Administrator username | `string` | `"azureuser"` | no |
| admin\_ssh\_public\_key | SSH public key for administrator account | `string` | — | **yes** |
| os\_disk\_size\_gb | OS disk size in GiB | `number` | `50` | no |
| dns\_zone\_name | Existing Azure DNS zone name | `string` | — | **yes** |
| dns\_zone\_resource\_group | Resource group containing the DNS zone | `string` | — | **yes** |
| dns\_record\_name | DNS A record name in the zone | `string` | `"mirror"` | no |
| tags | Additional resource tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| load\_balancer\_public\_ip | Public IP address of the Azure Load Balancer |
| load\_balancer\_id | Resource ID of the Load Balancer |
| vmss\_id | Resource ID of the Virtual Machine Scale Set |
| vmss\_identity\_principal\_id | Principal ID of the VMSS system-assigned managed identity |
| resource\_group\_name | Name of the resource group |
| dns\_fqdn | Fully qualified domain name of the DNS record |
| registry\_url | Full URL of the Docker Registry mirror |

## Prerequisites

### Packer image

Build the `ubuntu-docker-mirror` Managed Image for your Azure subscription before applying this module:

```bash
cd tfe-local-mirror-azure  # or ubuntu-docker-mirror-azure once available
packer init .
packer build \
  -var "subscription_id=<your-sub-id>" \
  -var "resource_group=rg-packer-images" \
  -var "location=eastus" .
```

The module selects the most-recently created image whose name starts with `image_name_prefix` and has the `Packer = true` tag.

### Networking

Supply an existing subnet ID (`subnet_id`). The VMSS instances are placed in this subnet; the Load Balancer uses a public IP. Ensure outbound internet access is available for Docker Hub pull-through caching.

### DNS

Supply an existing Azure DNS zone (`dns_zone_name`, `dns_zone_resource_group`). The module creates an A record pointing to the Load Balancer public IP.

## Examples

See [`examples/basic`](./examples/basic) for a complete working example.

## Tests

Native Terraform tests live in [`tests/`](./tests/). Run them with:

```bash
cd terraform/azure
terraform test
```
