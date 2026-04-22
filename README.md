# Packer Templates

A collection of [HashiCorp Packer](https://developer.hashicorp.com/packer) templates for building Google Compute Engine (GCE) machine images on Google Cloud Platform.

Each build lives in its own directory so it can be iterated on and run independently.

---

## Builds

| Directory | Description |
|-----------|-------------|
| [`gcp-ubuntu/`](./gcp-ubuntu/) | Ubuntu 24.04 LTS base image — updated and provisioned with common tooling |
| [`ubuntu-docker-mirror/`](./ubuntu-docker-mirror/) | Ubuntu 24.04 LTS with a local Docker Registry pull-through cache mirror |
| [`ubuntu-docker-local-container/`](./ubuntu-docker-local-container/) | Ubuntu 24.04 LTS with a specified container image pre-loaded into a local Docker Registry |

---

## Prerequisites

| Tool | Install |
|------|---------|
| [Packer](https://developer.hashicorp.com/packer/install) ≥ 1.9 | `brew install packer` / binary download |
| [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) | `brew install google-cloud-sdk` |
| GCP project with **Compute Engine API** enabled | [Enable API](https://console.cloud.google.com/flows/enableapi?apiid=compute.googleapis.com) |

### GCP IAM permissions

The identity running Packer (user or service account) needs:

- `roles/compute.instanceAdmin.v1`
- `roles/iam.serviceAccountUser` (if the build VM uses a service account)

---

## Authentication

### Interactive (local development)

```bash
gcloud auth application-default login
```

### Service account (CI/CD)

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account-key.json
```

Or use [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation) for keyless authentication.

---

## Running a build locally

Each template directory contains a `README.md` with full instructions. The general pattern is:

```bash
# 1. Move into the build directory
cd gcp-ubuntu          # or ubuntu-docker-mirror / ubuntu-docker-local-container

# 2. Install required plugins (one-time per machine)
packer init .

# 3. Check template formatting
packer fmt -check .

# 4. Validate the template (no GCP API calls made at this stage)
packer validate -var "project_id=YOUR_GCP_PROJECT_ID" .

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

---

## Build details

### 1. `gcp-ubuntu` — Ubuntu 24.04 LTS base image

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

### 2. `ubuntu-docker-mirror` — Local Docker registry pull-through cache

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

### 3. `ubuntu-docker-local-container` — Pre-loaded container in a local registry

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
│       └── validate.yml          # CI: fmt, validate, shellcheck
├── gcp-ubuntu/
│   ├── main.pkr.hcl              # Builder + build block
│   ├── variables.pkr.hcl         # Input variable declarations
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
- [Shell provisioner](https://developer.hashicorp.com/packer/docs/provisioners/shell)
