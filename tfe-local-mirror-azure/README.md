# tfe-local-mirror-azure

Packer template that builds an Azure Managed Image (Ubuntu 24.04 LTS) with Terraform
Enterprise pre-loaded into a local Docker registry. The resulting image is used for
air-gapped or offline TFE deployments where pulling the image at runtime is not permitted.

**Reference:** <https://developer.hashicorp.com/terraform/enterprise/deploy/docker>

---

## Prerequisites

- [Packer](https://developer.hashicorp.com/packer/install) ≥ 1.10
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) authenticated (`az login`)
- An **existing** Azure resource group to store the managed image
- IAM permissions: Contributor role on the resource group (or custom role with VM create/delete + image write)
- A valid Terraform Enterprise license file (`.hclic`) — **never commit this file**

---

## Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `subscription_id` | ✓ | | Azure subscription ID |
| `resource_group` | ✓ | | Existing resource group for the managed image |
| `location` | | `eastus` | Azure region |
| `vm_size` | | `Standard_D4s_v3` | Build VM size (≥4 vCPU, ≥16 GB recommended) |
| `image_name` | | `tfe-local-mirror` | Base name for the resulting managed image (timestamp appended) |
| `disk_size` | | `100` | OS disk size in GB |
| `tfe_version` | | `1.2.1` | TFE image tag — see [TFE releases](https://developer.hashicorp.com/terraform/enterprise/releases) |
| `tfe_license_file` | | `./files/terraform.hclic` | Local path to your `.hclic` license file |

---

## Authentication

Packer uses the Azure CLI token by default. Ensure you are logged in and have the correct subscription set:

```bash
az login
az account set --subscription "<SUBSCRIPTION_ID>"
```

Alternatively, set `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, and `ARM_TENANT_ID` environment variables for service principal auth.

---

## Quick Start

1. Create the destination resource group if it does not exist:

   ```bash
   az group create --name my-packer-images --location eastus
   ```

2. Copy your license file into the template directory (git-ignored):

   ```bash
   cp /path/to/your/terraform.hclic tfe-local-mirror-azure/files/terraform.hclic
   ```

3. Initialise plugins:

   ```bash
   packer init tfe-local-mirror-azure
   ```

4. Build the image:

   ```bash
   packer build \
     -var "subscription_id=$(az account show --query id -o tsv)" \
     -var "resource_group=my-packer-images" \
     tfe-local-mirror-azure
   ```

   Override further as needed:

   ```bash
   packer build \
     -var "subscription_id=$(az account show --query id -o tsv)" \
     -var "resource_group=my-packer-images" \
     -var "location=westeurope" \
     -var "tfe_version=1.3.0" \
     -var "tfe_license_file=/absolute/path/terraform.hclic" \
     tfe-local-mirror-azure
   ```

---

## Security Notes

- The license file is uploaded to `/tmp/tfe.hclic` on the build VM, used to authenticate to `images.releases.hashicorp.com`, and **deleted** before the image is captured.
- The `waagent -deprovision+user` step at the end generalises the image (required by Azure); SSH host keys and the build user account are removed.
- `*.hclic` is listed in `.gitignore` — do not force-add it.
- The `files/` directory contains only a `.gitkeep`; the actual license file is git-ignored.
