# gcp-ubuntu

Packer template that builds a **Google Compute Engine machine image** running the latest **Ubuntu 24.04 LTS**, updated and provisioned with common base tooling.

## What it does

1. Launches a temporary GCP VM from the official `ubuntu-2404-lts-amd64` source image family.
2. Runs a `shell` provisioner that:
   - Waits for `cloud-init` to finish.
   - Runs `apt-get update` and `apt-get upgrade`.
   - Installs `curl`, `wget`, `unzip`, `git`, and `ca-certificates`.
3. Snapshots the VM into a new Compute Engine image and destroys the temporary VM.

The resulting image is tagged with `image_family = "ubuntu-custom"` (configurable) so consumers can always reference `family/ubuntu-custom` to get the latest build.

## Prerequisites

| Tool | Version |
|------|---------|
| [Packer](https://developer.hashicorp.com/packer/install) | ≥ 1.9 |
| [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) (`gcloud`) | any recent |
| GCP project with **Compute Engine API** enabled | — |
| IAM role `roles/compute.instanceAdmin.v1` + `roles/iam.serviceAccountUser` on the build service account | — |

## Authentication

Packer reads credentials from [Application Default Credentials](https://cloud.google.com/docs/authentication/application-default-credentials).  
The simplest approach for local builds:

```bash
gcloud auth application-default login
```

For CI/CD, use a service account key or Workload Identity Federation.

## Variables

| Name | Default | Description |
|------|---------|-------------|
| `project_id` | *(required)* | GCP project ID |
| `zone` | `us-central1-a` | Zone for the temporary build VM |
| `machine_type` | `e2-standard-2` | Machine type for the build VM |
| `image_name` | `ubuntu-2404-lts` | Base name of the output image (timestamp appended) |
| `image_family` | `ubuntu-custom` | Image family for the output image |
| `disk_size` | `20` | Boot disk size in GB |

## Local build

```bash
# 1. Authenticate with GCP
gcloud auth application-default login

# 2. Install the required Packer plugin
packer init .

# 3. (Optional) Check formatting
packer fmt -check .

# 4. Validate the template
packer validate -var "project_id=MY_PROJECT_ID" .

# 5. Build the image
packer build -var "project_id=MY_PROJECT_ID" .
```

To customise any variable pass additional `-var` flags or create a `*.pkrvars.hcl` file:

```hcl
# my.pkrvars.hcl  (never commit this file – it is git-ignored)
project_id   = "my-gcp-project"
zone         = "europe-west1-b"
machine_type = "e2-standard-4"
image_family = "my-ubuntu-base"
```

```bash
packer build -var-file="my.pkrvars.hcl" .
```

## Useful links

- [Packer GoogleCompute builder](https://developer.hashicorp.com/packer/integrations/hashicorp/googlecompute/latest/components/builder/googlecompute)
- [Packer HCL2 configuration language](https://developer.hashicorp.com/packer/docs/templates/hcl_templates)
- [Packer CLI reference](https://developer.hashicorp.com/packer/docs/commands)
- [GCP Compute Engine images](https://cloud.google.com/compute/docs/images)
