# ubuntu-docker-local-container

Packer template that builds a Google Compute Engine machine image running **Ubuntu 24.04 LTS** with a **pre-loaded container image** stored in a local Docker Registry that starts automatically on boot — enabling fully offline container workloads.

## What it does

1. Installs Docker CE from the official Docker apt repository.
2. Starts a temporary local Docker Registry (`registry:2`).
3. Pulls the specified `container_image` from Docker Hub into the build VM.
4. Tags the image and pushes it into the local registry (persisted at `/var/lib/registry`).
5. Installs a `systemd` service (`docker-local-registry`) that starts the registry on every boot.
6. Configures the Docker daemon to use `http://localhost:5000` as a registry mirror, so the pre-loaded image is served without internet access.

When a VM boots from this image it can immediately run the pre-loaded container — no internet access or Docker Hub credentials required.

## Architecture

```
Packer build time:
  Docker Hub  ──►  docker pull nginx:latest
                        │
                        └──► tag as localhost:5000/library/nginx:latest
                                   │
                                   └──► push to /var/lib/registry  (baked into image)

VM runtime:
  docker run nginx
      │
      ▼
  Docker daemon  ──►  localhost:5000 (pre-seeded registry)
                              │
                              └── HIT  →  served from /var/lib/registry (no internet needed)
```

## Prerequisites

| Tool | Version |
|------|---------|
| [Packer](https://developer.hashicorp.com/packer/install) | >= 1.9 |
| [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) (`gcloud`) | any recent |
| GCP project with **Compute Engine API** enabled | — |
| IAM role `roles/compute.instanceAdmin.v1` + `roles/iam.serviceAccountUser` | — |

## Authentication

```bash
gcloud auth application-default login
```

## Variables

| Name | Default | Description |
|------|---------|-------------|
| `project_id` | *(required)* | GCP project ID |
| `zone` | `us-central1-a` | Zone for the temporary build VM |
| `machine_type` | `e2-standard-2` | Machine type for the build VM |
| `image_name` | `ubuntu-docker-local-container` | Base name of the output image |
| `image_family` | `ubuntu-docker-local-container` | Image family for the output image |
| `disk_size` | `50` | Boot disk size in GB (must be large enough for the pre-loaded images) |
| `container_image` | `nginx:latest` | The container image to pre-load into the local registry |

## Local build

```bash
# 1. Authenticate with GCP
gcloud auth application-default login

# 2. Install the required Packer plugin
packer init .

# 3. Validate the template
packer validate \
  -var "project_id=MY_PROJECT_ID" \
  -var "container_image=nginx:latest" .

# 4. Build the image
packer build \
  -var "project_id=MY_PROJECT_ID" \
  -var "container_image=nginx:latest" .
```

To pre-load a custom application image:

```hcl
# my.pkrvars.hcl  (never commit this file – it is git-ignored)
project_id      = "my-gcp-project"
zone            = "europe-west1-b"
image_family    = "my-app-image"
container_image = "myorg/myapp:1.2.3"
disk_size       = 100
```

```bash
packer build -var-file="my.pkrvars.hcl" .
```

## Using the pre-loaded image after boot

```bash
# Verify the local registry is running
sudo systemctl status docker-local-registry

# List all tags available in the local registry
curl -s http://localhost:5000/v2/_catalog | python3 -m json.tool

# Pull the pre-loaded image (served from the local registry)
docker pull nginx:latest

# Run the pre-loaded image
docker run --rm -p 8080:80 nginx:latest
```

> **Note:** The first `docker pull` after boot is served directly from the local registry at `localhost:5000`. No internet access is required for the pre-loaded image.

## Useful links

- [Packer GoogleCompute builder](https://developer.hashicorp.com/packer/integrations/hashicorp/googlecompute/latest/components/builder/googlecompute)
- [Docker Registry v2 configuration](https://distribution.github.io/distribution/about/configuration/)
- [Docker registry as a pull-through cache](https://docs.docker.com/docker-hub/mirror/)
- [Packer CLI reference](https://developer.hashicorp.com/packer/docs/commands)
