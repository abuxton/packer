# `tfe-local-mirror` — Terraform Enterprise local image mirror

Builds a Google Compute Engine image (Ubuntu 24.04 LTS) that pre-loads the
**Terraform Enterprise** and **hashicorp/tfc-agent** container images into a local Docker Registry v2
instance. VMs started from this image can launch TFE immediately, without
requiring outbound access to `images.releases.hashicorp.com`.

## References

- [Deploy TFE with Docker](https://developer.hashicorp.com/terraform/enterprise/deploy/docker)
- [TFE releases and version tags](https://developer.hashicorp.com/terraform/enterprise/releases)
- [TFE configuration reference](https://developer.hashicorp.com/terraform/enterprise/deploy/reference/configuration)
- [GoogleCompute Packer builder](https://developer.hashicorp.com/packer/integrations/hashicorp/googlecompute)

---

## Prerequisites

| Tool | Install |
|------|---------|
| [Packer](https://developer.hashicorp.com/packer/install) ≥ 1.9 | `brew install packer` |
| [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) | `brew install google-cloud-sdk` |
| GCP project with Compute Engine API enabled | [Enable API](https://console.cloud.google.com/flows/enableapi?apiid=compute.googleapis.com) |
| A valid HashiCorp TFE license file (`.hclic`) | Provided by HashiCorp |

### GCP IAM permissions

- `roles/compute.instanceAdmin.v1`
- `roles/iam.serviceAccountUser` (if the build VM uses a service account)

### GCP authentication

```bash
gcloud auth application-default login
```

---

## License file handling

The `.hclic` license file is **only** needed during the Packer build, to
authenticate a `docker login` to `images.releases.hashicorp.com`. It is:

- Uploaded to the build VM via a Packer `file` provisioner
- Used once for `docker login --password-stdin`
- **Deleted from the VM** before the image is captured
- Never embedded in the resulting GCE image

Place your license file at `./files/terraform.hclic` (this path is
git-ignored), or provide the path at build time with
`-var "tfe_license_file=/path/to/your.hclic"`.

> **Never commit `.hclic` files to source control.**

---

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `project_id` | *(required)* | GCP project ID |
| `tfe_version` | *(required)* | TFE image tag, e.g. `v202506-1` — see [releases](https://developer.hashicorp.com/terraform/enterprise/releases) |
| `tfe_license_file` | `./files/terraform.hclic` | Local path to your `.hclic` license file |
| `zone` | `us-central1-a` | GCP zone for the build instance |
| `machine_type` | `e2-standard-4` | GCP machine type (4 vCPU / 16 GB recommended for image operations) |
| `image_name` | `tfe-local-mirror` | Base name of the output image (timestamp appended) |
| `image_family` | `tfe-local-mirror` | Image family for the output image |
| `disk_size` | `100` | Boot disk size in GB (100 GB recommended to accommodate TFE image layers) |

---

## Running the build

```bash
# 1. Move into the template directory
cd tfe-local-mirror

# 2. Install required plugins (one-time per machine)
packer init .

# 3. Check template formatting
packer fmt -check .

# 4. Validate the template (no GCP API calls; uses a placeholder for the license)
#    Create a dummy file for validation only:
echo "placeholder" > /tmp/placeholder.hclic
packer validate \
  -var "project_id=my-gcp-project" \
  -var "tfe_version=v202506-1" \
  -var "tfe_license_file=/tmp/placeholder.hclic" \
  .

# 5. Build the image (requires a real license and GCP credentials)
packer build \
  -var "project_id=my-gcp-project" \
  -var "tfe_version=v202506-1" \
  -var "tfe_license_file=/path/to/terraform.hclic" \
  .
```

Or use a `*.pkrvars.hcl` file (git-ignored automatically):

```hcl
# tfe.pkrvars.hcl  ← never commit this file
project_id       = "my-gcp-project"
tfe_version      = "v202506-1"
tfe_license_file = "/path/to/terraform.hclic"
zone             = "europe-west2-b"
```

```bash
packer build -var-file="tfe.pkrvars.hcl" .
```

---

## What the build does

1. Boots a GCE Ubuntu 24.04 VM
2. Installs Docker CE from the official Docker apt repository
3. Configures `/etc/docker/daemon.json` with `insecure-registries: ["localhost:5000"]`
4. Pulls `registry:2` and starts a temporary seed registry
5. Authenticates to `images.releases.hashicorp.com` using your license as the password
6. Pulls `hashicorp/terraform-enterprise:<tfe_version>`
7. Pulls `hashicorp/tfc-agent:latest` from Docker Hub
8. Retags both images as `localhost:5000/hashicorp/...` and pushes them into the local registry
9. Logs out from HashiCorp registry and removes all credential files
10. Removes the upstream image layers (only local copies are kept)
11. Installs a `tfe-local-registry` systemd service that starts the registry on boot
12. Verifies both images are accessible via the registry API

---

## Using the resulting image

When a VM is started from this image:

- The local registry starts automatically on port `5000`
- The TFE image is available at `localhost:5000/hashicorp/terraform-enterprise:<tfe_version>`
- The TFC agent image is available at `localhost:5000/hashicorp/tfc-agent:latest`

Reference it in your Docker Compose deployment file:

```yaml
# docker-compose.yml
name: terraform-enterprise
services:
  tfe:
    image: localhost:5000/hashicorp/terraform-enterprise:<tfe_version>
    environment:
      TFE_LICENSE: "<your-license-content>"
      TFE_HOSTNAME: "terraform.example.com"
      TFE_ENCRYPTION_PASSWORD: "<encryption-password>"
      TFE_OPERATIONAL_MODE: "disk"
      TFE_DISK_CACHE_VOLUME_NAME: "${COMPOSE_PROJECT_NAME}_terraform-enterprise-cache"
      TFE_TLS_CERT_FILE: "/etc/ssl/private/terraform-enterprise/cert.pem"
      TFE_TLS_KEY_FILE: "/etc/ssl/private/terraform-enterprise/key.pem"
      TFE_TLS_CA_BUNDLE_FILE: "/etc/ssl/private/terraform-enterprise/bundle.pem"
      TFE_IACT_SUBNETS: "10.0.0.0/8"
    cap_add:
      - IPC_LOCK
    read_only: true
    tmpfs:
      - /tmp:mode=01777
      - /run
      - /var/log/terraform-enterprise
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - type: bind
        source: /var/run/docker.sock
        target: /run/docker.sock
      - type: bind
        source: ./certs
        target: /etc/ssl/private/terraform-enterprise
      - type: bind
        source: /var/lib/terraform-enterprise
        target: /var/lib/terraform-enterprise
      - type: volume
        source: terraform-enterprise-cache
        target: /var/cache/tfe-task-worker/terraform
volumes:
  terraform-enterprise-cache:
```

Refer to the [TFE Docker deployment guide](https://developer.hashicorp.com/terraform/enterprise/deploy/docker)
and [configuration reference](https://developer.hashicorp.com/terraform/enterprise/deploy/reference/configuration)
for all required environment variables and deployment modes.

---

## Repository structure

```
tfe-local-mirror/
├── main.pkr.hcl              # Packer packer{} + source + build blocks
├── variables.pkr.hcl         # Input variable declarations
├── files/
│   └── .gitkeep              # Place terraform.hclic here (git-ignored)
├── scripts/
│   └── setup-tfe-mirror.sh   # Provisioner: Docker install, pull, mirror, cleanup
└── README.md                 # This file
```
