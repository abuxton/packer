# ubuntu-docker-mirror

Packer template that builds a Google Compute Engine machine image running **Ubuntu 24.04 LTS** with a **local Docker Registry v2 pull-through cache mirror** pre-installed and configured to start automatically on boot. The image also pre-caches the **HCP Terraform agent** (`hashicorp/tfc-agent`) and ships an opt-in systemd service for running it.

## What it does

1. Installs Docker CE from the official Docker apt repository.
2. Pulls the `registry:2` image.
3. Configures a Docker Registry v2 instance as a **pull-through proxy cache** for Docker Hub (`registry-1.docker.io`).
4. Installs a `systemd` service (`docker-registry-mirror`) that starts the registry automatically on boot.
5. Configures the Docker daemon (`/etc/docker/daemon.json`) to use `http://localhost:5000` as a registry mirror.
6. Pre-pulls `hashicorp/tfc-agent:<version>` through the mirror so the image is available locally without requiring a Docker Hub pull at runtime.
7. Installs an opt-in `systemd` service (`tfc-agent`) and a template environment file (`/etc/tfc-agent/env.example`).

When any Docker client on the resulting VM pulls an image, the request is transparently routed through the local registry. The registry fetches the image from Docker Hub on the first pull and stores it locally in `/var/lib/registry` for all subsequent pulls — reducing latency and egress costs.

## Architecture

```
docker pull nginx
      │
      ▼
Docker daemon  ──►  localhost:5000 (registry:2 pull-through cache)
                              │
                              ├── HIT  →  served from /var/lib/registry
                              └── MISS →  fetched from registry-1.docker.io and cached
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
| `image_name` | `ubuntu-docker-mirror` | Base name of the output image |
| `image_family` | `ubuntu-docker-mirror` | Image family for the output image |
| `disk_size` | `50` | Boot disk size in GB (larger to accommodate the registry cache) |
| `tfc_agent_version` | `1.22.0` | Version of `hashicorp/tfc-agent` to pre-pull into the mirror |

## Local build

```bash
# 1. Authenticate with GCP
gcloud auth application-default login

# 2. Install the required Packer plugin
packer init .

# 3. Validate the template
packer validate -var "project_id=MY_PROJECT_ID" .

# 4. Build the image
packer build -var "project_id=MY_PROJECT_ID" .
```

Using a vars file:

```hcl
# my.pkrvars.hcl  (never commit this file – it is git-ignored)
project_id        = "my-gcp-project"
zone              = "europe-west1-b"
image_family      = "my-docker-mirror"
tfc_agent_version = "1.22.0"
```

```bash
packer build -var-file="my.pkrvars.hcl" .
```

## Using the mirror after boot

When you start a VM from this image, the registry mirror starts automatically. Docker is already configured to use it:

```bash
# Verify the mirror is running
sudo systemctl status docker-registry-mirror

# Verify Docker is configured to use it
sudo docker info | grep -A2 "Registry Mirrors"

# Pull an image – the first pull fetches from Docker Hub and caches locally
docker pull ubuntu:22.04

# Subsequent pulls are served from the local cache
docker pull ubuntu:22.04
```

## Running the HCP Terraform agent

The `hashicorp/tfc-agent` image is pre-cached in the local mirror during the Packer build. A systemd unit is installed but **disabled by default** — you must configure the agent token before enabling it.

### Managed service (recommended)

```bash
# 1. Copy and edit the environment template
sudo cp /etc/tfc-agent/env.example /etc/tfc-agent/env
sudo chmod 600 /etc/tfc-agent/env
sudo vi /etc/tfc-agent/env   # set TFC_AGENT_TOKEN (and optionally TFC_AGENT_NAME)

# 2. Enable and start the service
sudo systemctl enable --now tfc-agent

# 3. Check status
sudo systemctl status tfc-agent
sudo journalctl -u tfc-agent -f
```

The service will restart automatically on failure and will not start if `/etc/tfc-agent/env` is missing.

### One-shot (ad hoc)

```bash
export TFC_AGENT_TOKEN=<your-token>
export TFC_AGENT_NAME=<optional-name>
docker run --platform=linux/amd64 -e TFC_AGENT_TOKEN -e TFC_AGENT_NAME hashicorp/tfc-agent:1.22.0
```

Refer to the [HCP Terraform agent documentation](https://developer.hashicorp.com/terraform/cloud-docs/agents/agents) for agent pool setup, token creation, and workspace configuration.

## Useful links

- [Packer GoogleCompute builder](https://developer.hashicorp.com/packer/integrations/hashicorp/googlecompute/latest/components/builder/googlecompute)
- [Docker Registry pull-through cache](https://docs.docker.com/docker-hub/mirror/)
- [Docker Registry v2 configuration](https://distribution.github.io/distribution/about/configuration/)
- [HCP Terraform agent documentation](https://developer.hashicorp.com/terraform/cloud-docs/agents/agents)
- [Packer CLI reference](https://developer.hashicorp.com/packer/docs/commands)
