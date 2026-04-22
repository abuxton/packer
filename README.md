# Packer Templates

A collection of [HashiCorp Packer](https://developer.hashicorp.com/packer) templates for building machine images across multiple cloud providers and platforms: Google Cloud Platform (GCE), Amazon Web Services (AMI), Microsoft Azure (Managed Image), and VMware vSphere.

Each build lives in its own directory so it can be iterated on and run independently.

---

## Builds

| Directory | Cloud / Platform | Description |
|-----------|-----------------|-------------|
| [`gcp-ubuntu/`](./gcp-ubuntu/) | GCP | Ubuntu 24.04 LTS base image — updated and provisioned with common tooling |
| [`ubuntu-docker-mirror/`](./ubuntu-docker-mirror/) | GCP | Ubuntu 24.04 LTS with a local Docker Registry pull-through cache mirror |
| [`ubuntu-docker-local-container/`](./ubuntu-docker-local-container/) | GCP | Ubuntu 24.04 LTS with a specified container image pre-loaded into a local Docker Registry |
| [`tfe-local-mirror-gcp/`](./tfe-local-mirror-gcp/) | GCP | Ubuntu 24.04 LTS GCE image with Terraform Enterprise pre-loaded into a local Docker Registry |
| [`tfe-local-mirror-aws/`](./tfe-local-mirror-aws/) | AWS | Ubuntu 24.04 LTS AMI with Terraform Enterprise pre-loaded into a local Docker Registry |
| [`tfe-local-mirror-azure/`](./tfe-local-mirror-azure/) | Azure | Ubuntu 24.04 LTS Managed Image with Terraform Enterprise pre-loaded into a local Docker Registry |
| [`tfe-local-mirror-vmware/`](./tfe-local-mirror-vmware/) | VMware vSphere | Ubuntu 24.04 LTS vSphere VM template with Terraform Enterprise pre-loaded into a local Docker Registry |

---

## Prerequisites

### Common

| Tool | Install |
|------|---------|
| [Packer](https://developer.hashicorp.com/packer/install) ≥ 1.10 | `brew install packer` / binary download |
| [go-task](https://taskfile.dev/installation/) (optional) | `brew install go-task` — task runner for common operations |

### GCP builds (`gcp-ubuntu`, `ubuntu-docker-mirror`, `ubuntu-docker-local-container`, `tfe-local-mirror-gcp`)

| Tool | Install |
|------|---------|
| [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) | `brew install google-cloud-sdk` |
| GCP project with **Compute Engine API** enabled | [Enable API](https://console.cloud.google.com/flows/enableapi?apiid=compute.googleapis.com) |

Required IAM roles for the identity running Packer:

- `roles/compute.instanceAdmin.v1`
- `roles/iam.serviceAccountUser` (if the build VM uses a service account)

### AWS builds (`tfe-local-mirror-aws`)

AWS credentials configured via any standard method (`aws configure`, `AWS_*` environment variables, or an IAM instance profile).

Required IAM permissions:

- `ec2:RunInstances`, `ec2:DescribeImages`, `ec2:CreateImage`, `ec2:TerminateInstances`
- `ec2:CreateTags`, `ec2:DescribeSubnets`, `ec2:DescribeSecurityGroups`

### Azure builds (`tfe-local-mirror-azure`)

| Tool | Install |
|------|---------|
| [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) | `brew install azure-cli` |

Required: Contributor role on the destination resource group (or a custom role with VM create/delete and image write).

### VMware builds (`tfe-local-mirror-vmware`)

- vCenter Server or ESXi host reachable from the machine running Packer
- vSphere permissions: VM create/delete, datastore access
- Ubuntu 24.04 LTS server ISO accessible to the build (datastore or public URL)

### TFE builds (`tfe-local-mirror-*`)

All four TFE builds additionally require:

- A valid **Terraform Enterprise license file** (`.hclic`) — provided by HashiCorp, **never commit this file**
- Place it at `<template-dir>/files/terraform.hclic` (git-ignored) or supply the path via `-var "tfe_license_file=..."`

---

## Authentication

### GCP — interactive (local development)

```bash
gcloud auth application-default login
```

### GCP — service account (CI/CD)

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account-key.json
```

Or use [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation) for keyless authentication.

### AWS

```bash
aws configure
# or export AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN
```

### Azure

```bash
az login
az account set --subscription "<SUBSCRIPTION_ID>"
```

For service principal authentication, set `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, and `ARM_TENANT_ID`.

### VMware vSphere

Credentials are passed as Packer variables (`vcenter_server`, `vcenter_username`, `vcenter_password`). Use a `*.pkrvars.hcl` file (git-ignored) to avoid passing them on the command line.

---

## Running a build locally

Each template directory contains a `README.md` with full instructions. The general pattern is:

```bash
# 1. Move into the build directory
cd <template-dir>

# 2. Install required plugins (one-time per machine)
packer init .

# 3. Check template formatting
packer fmt -check .

# 4. Validate the template
packer validate -var "project_id=YOUR_GCP_PROJECT_ID" .   # GCP example

# 5. Build the image
packer build -var "project_id=YOUR_GCP_PROJECT_ID" .
```

### Providing variables

Pass variables inline:

```bash
packer build \
  -var "project_id=my-project" \
  -var "zone=europe-west1-b" \
  -var "machine_type=e2-standard-4" \
  .
```

Or use a variables file (`*.pkrvars.hcl` files are git-ignored to prevent accidental credential leaks):

```hcl
# my.pkrvars.hcl  ← never commit this file
project_id   = "my-gcp-project"
zone         = "europe-west1-b"
machine_type = "e2-standard-4"
```

```bash
packer build -var-file="my.pkrvars.hcl" .
```

### Using the Taskfile

A [`Taskfile.yml`](./Taskfile.yml) is included for running common operations across all templates:

```bash
task packer:init      # packer init in every template directory
task packer:fmt       # packer fmt -check in every template directory
task packer:validate  # packer validate in every template directory (pass VALIDATE_ARGS="...")
task packer:build     # packer build in every template directory (pass BUILD_ARGS="...")

# Single-template helpers
task packer:init:one     TEMPLATE=gcp-ubuntu
task packer:validate:one TEMPLATE=tfe-local-mirror-aws VALIDATE_ARGS="-syntax-only"
task packer:build:one    TEMPLATE=tfe-local-mirror-gcp BUILD_ARGS="-var project_id=my-project ..."
```

---

## Build details

### 1. `gcp-ubuntu` — Ubuntu 24.04 LTS base image (GCP)

Builds a clean, fully-updated Ubuntu 24.04 LTS GCE image from the official
`ubuntu-2404-lts-amd64` source image family.

**Quick start:**

```bash
cd gcp-ubuntu
packer init .
packer build -var "project_id=MY_PROJECT" .
```

See [`gcp-ubuntu/README.md`](./gcp-ubuntu/README.md) for full documentation.

---

### 2. `ubuntu-docker-mirror` — Local Docker registry pull-through cache (GCP)

Builds a GCE image that runs a Docker Registry v2 configured as a
**pull-through cache** for Docker Hub. On first pull the image is fetched from
Docker Hub and stored in `/var/lib/registry`; subsequent pulls are served
locally.

**Quick start:**

```bash
cd ubuntu-docker-mirror
packer init .
packer build -var "project_id=MY_PROJECT" .
```

See [`ubuntu-docker-mirror/README.md`](./ubuntu-docker-mirror/README.md) for full documentation.

---

### 3. `ubuntu-docker-local-container` — Pre-loaded container in a local registry (GCP)

Builds a GCE image that pulls a specified container image **at build time**
and stores it in a local Docker Registry. VMs started from this image can run
the pre-loaded container immediately, with no internet access required.

**Quick start:**

```bash
cd ubuntu-docker-local-container
packer init .
packer build \
  -var "project_id=MY_PROJECT" \
  -var "container_image=nginx:latest" \
  .
```

See [`ubuntu-docker-local-container/README.md`](./ubuntu-docker-local-container/README.md) for full documentation.

---

### 4. `tfe-local-mirror-gcp` — Terraform Enterprise local image mirror (GCP)

Builds a GCE image (Ubuntu 24.04 LTS) that pre-loads the Terraform Enterprise
container image into a local Docker Registry v2. VMs started from this image
can launch TFE immediately without requiring outbound access to
`images.releases.hashicorp.com`.

**Quick start:**

```bash
cp /path/to/terraform.hclic tfe-local-mirror-gcp/files/terraform.hclic
cd tfe-local-mirror-gcp
packer init .
packer build \
  -var "project_id=MY_PROJECT" \
  -var "tfe_version=v202506-1" \
  -var "tfe_license_file=./files/terraform.hclic" \
  .
```

See [`tfe-local-mirror-gcp/README.md`](./tfe-local-mirror-gcp/README.md) for full documentation.

---

### 5. `tfe-local-mirror-aws` — Terraform Enterprise local image mirror (AWS)

Builds an AWS AMI (Ubuntu 24.04 LTS) that pre-loads the Terraform Enterprise
container image into a local Docker Registry v2. Instances launched from this
AMI can run TFE without internet access to the HashiCorp image registry.

**Quick start:**

```bash
cp /path/to/terraform.hclic tfe-local-mirror-aws/files/terraform.hclic
packer init tfe-local-mirror-aws
packer build \
  -var "tfe_version=v202506-1" \
  -var "tfe_license_file=./files/terraform.hclic" \
  tfe-local-mirror-aws
```

See [`tfe-local-mirror-aws/README.md`](./tfe-local-mirror-aws/README.md) for full documentation.

---

### 6. `tfe-local-mirror-azure` — Terraform Enterprise local image mirror (Azure)

Builds an Azure Managed Image (Ubuntu 24.04 LTS) that pre-loads the Terraform
Enterprise container image into a local Docker Registry v2. VMs started from
this image can run TFE without outbound access to the HashiCorp image registry.

**Quick start:**

```bash
cp /path/to/terraform.hclic tfe-local-mirror-azure/files/terraform.hclic
az group create --name my-packer-images --location eastus
packer init tfe-local-mirror-azure
packer build \
  -var "subscription_id=$(az account show --query id -o tsv)" \
  -var "resource_group=my-packer-images" \
  -var "tfe_version=v202506-1" \
  -var "tfe_license_file=./files/terraform.hclic" \
  tfe-local-mirror-azure
```

See [`tfe-local-mirror-azure/README.md`](./tfe-local-mirror-azure/README.md) for full documentation.

---

### 7. `tfe-local-mirror-vmware` — Terraform Enterprise local image mirror (VMware vSphere)

Builds a VMware vSphere VM template (Ubuntu 24.04 LTS) that pre-loads the
Terraform Enterprise container image into a local Docker Registry v2. The
template uses Ubuntu's cloud-init **autoinstall** for an unattended OS
installation. VMs cloned from this template can run TFE in air-gapped
environments.

**Quick start:**

```bash
cp /path/to/terraform.hclic tfe-local-mirror-vmware/files/terraform.hclic
packer init tfe-local-mirror-vmware
packer build \
  -var "vcenter_server=vcenter.example.com" \
  -var "vcenter_username=administrator@vsphere.local" \
  -var "vcenter_password=<password>" \
  -var "cluster=ClusterName" \
  -var "datastore=DatastoreName" \
  -var "network=VM Network" \
  -var "tfe_version=v202506-1" \
  -var "tfe_license_file=./files/terraform.hclic" \
  tfe-local-mirror-vmware
```

See [`tfe-local-mirror-vmware/README.md`](./tfe-local-mirror-vmware/README.md) for full documentation.

---

## CI / Validation workflow

The repository includes a GitHub Actions workflow (`.github/workflows/validate.yml`) that runs on every push and pull request to `main`:

| Job | What it does |
|-----|-------------|
| **Format Check** | Runs `packer fmt -check` on every template directory |
| **Validate Templates** | Runs `packer init` + `packer validate` on every template |
| **Shell Script Lint** | Runs `shellcheck` on all provisioner shell scripts |

To enable full `packer validate` with real GCP project resolution, set the following in your repository settings:

- **Variable** `GCP_PROJECT_ID` — your GCP project ID
- **Secret** `GCP_CREDENTIALS` — contents of a GCP service account JSON key

---

## Repository structure

```
.
├── .github/
│   └── workflows/
│       └── validate.yml                    # CI: fmt, validate, shellcheck
├── gcp-ubuntu/
│   ├── main.pkr.hcl
│   ├── variables.pkr.hcl
│   └── README.md
├── ubuntu-docker-mirror/
│   ├── main.pkr.hcl
│   ├── variables.pkr.hcl
│   ├── scripts/
│   │   └── setup-docker-mirror.sh
│   └── README.md
├── ubuntu-docker-local-container/
│   ├── main.pkr.hcl
│   ├── variables.pkr.hcl
│   ├── scripts/
│   │   └── setup-docker-local.sh
│   └── README.md
├── tfe-local-mirror-gcp/
│   ├── main.pkr.hcl
│   ├── variables.pkr.hcl
│   ├── files/
│   │   └── .gitkeep                        # Place terraform.hclic here (git-ignored)
│   └── README.md
├── tfe-local-mirror-aws/
│   ├── main.pkr.hcl
│   ├── variables.pkr.hcl
│   ├── files/
│   │   └── .gitkeep
│   └── README.md
├── tfe-local-mirror-azure/
│   ├── main.pkr.hcl
│   ├── variables.pkr.hcl
│   ├── files/
│   │   └── .gitkeep
│   └── README.md
├── tfe-local-mirror-vmware/
│   ├── main.pkr.hcl
│   ├── variables.pkr.hcl
│   ├── files/
│   │   └── .gitkeep
│   ├── http/
│   │   └── user-data                       # cloud-init autoinstall seed
│   └── README.md
├── scripts/
│   └── setup-tfe-mirror.sh                 # Shared TFE provisioner script
├── Taskfile.yml                            # Task runner for common operations
├── .gitignore
└── README.md
```

---

## Packer documentation

- [Packer documentation home](https://developer.hashicorp.com/packer/docs)
- [HCL2 template format](https://developer.hashicorp.com/packer/docs/templates/hcl_templates)
- [Variable definitions](https://developer.hashicorp.com/packer/docs/templates/hcl_templates/variables)
- [packer init](https://developer.hashicorp.com/packer/docs/commands/init)
- [packer validate](https://developer.hashicorp.com/packer/docs/commands/validate)
- [packer build](https://developer.hashicorp.com/packer/docs/commands/build)
- [packer fmt](https://developer.hashicorp.com/packer/docs/commands/fmt)
- [GoogleCompute builder](https://developer.hashicorp.com/packer/integrations/hashicorp/googlecompute)
- [Amazon EBS builder](https://developer.hashicorp.com/packer/integrations/hashicorp/amazon/latest/components/builder/ebs)
- [Azure ARM builder](https://developer.hashicorp.com/packer/integrations/hashicorp/azure/latest/components/builder/arm)
- [vSphere ISO builder](https://developer.hashicorp.com/packer/integrations/hashicorp/vsphere/latest/components/builder/vsphere-iso)
- [Shell provisioner](https://developer.hashicorp.com/packer/docs/provisioners/shell)
- [Terraform Enterprise releases](https://developer.hashicorp.com/terraform/enterprise/releases)
- [Deploy TFE with Docker](https://developer.hashicorp.com/terraform/enterprise/deploy/docker)
