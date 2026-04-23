# tfe-local-mirror-vmware

Packer template that builds a VMware vSphere VM template (Ubuntu 24.04 LTS) with Terraform
Enterprise and `hashicorp/tfc-agent:latest` pre-loaded into a local Docker registry. The resulting vSphere template is used
for air-gapped or offline TFE deployments where pulling the image at runtime is not permitted.

**Reference:** <https://developer.hashicorp.com/terraform/enterprise/deploy/docker>

---

## Prerequisites

- [Packer](https://developer.hashicorp.com/packer/install) ≥ 1.10
- vCenter Server or ESXi host reachable from the machine running Packer
- vSphere permissions: VM create/delete, datastore access, content library (if used)
- The Ubuntu 24.04 LTS server ISO accessible to the build — either:
  - Uploaded to a vSphere datastore, or
  - Reachable via HTTP (the default points to Ubuntu's public mirrors)
- A valid Terraform Enterprise license file (`.hclic`) — **never commit this file**

---

## Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `vcenter_server` | ✓ | | Hostname or IP of vCenter Server |
| `vcenter_username` | ✓ | | vCenter username (e.g. `administrator@vsphere.local`) |
| `vcenter_password` | ✓ | | vCenter password (sensitive) |
| `cluster` | ✓ | | vSphere cluster or ESXi host name |
| `datastore` | ✓ | | vSphere datastore for build VM disks |
| `network` | ✓ | | vSphere port group / network name |
| `insecure_connection` | | `false` | Allow self-signed TLS cert (set `true` for lab environments) |
| `datacenter` | | `""` | vSphere datacenter name (optional if only one datacenter) |
| `folder` | | `""` | vSphere VM folder path |
| `vm_name` | | `tfe-local-mirror` | Base VM template name (timestamp appended) |
| `cpus` | | `4` | Number of vCPUs |
| `ram_mb` | | `16384` | RAM in MB |
| `disk_size` | | `100` | Root disk size in GB |
| `iso_url` | | Ubuntu 24.04.4 public URL | ISO URL or datastore path |
| `iso_checksum` | | `file:…/SHA256SUMS` | Checksum source — set to `sha256:<hash>` or `none` if using a local ISO |
| `ssh_password` | | `packer` | Build user password (sensitive, locked after build) |
| `tfe_version` | | `1.2.1` | TFE image tag — see [TFE releases](https://developer.hashicorp.com/terraform/enterprise/releases) |
| `tfe_license_file` | | `./files/terraform.hclic` | Local path to your `.hclic` license file |

---

## How Autoinstall Works

The template uses Ubuntu 24.04's cloud-init **autoinstall** mechanism to perform an unattended
OS install. A seed ISO is constructed from `http/user-data` and `http/meta-data` and attached
to the build VM as a virtual CD (`cd_label = "cidata"`). GRUB is patched at boot to inject the
`autoinstall` kernel parameter.

The `packer` user created by autoinstall has password `packer` (overridable via `ssh_password`).
The password is **locked** (`passwd -l packer`) at the end of the provisioning phase so no known
credential remains on the resulting template.

---

## Quick Start

1. Copy your license file into the template directory (git-ignored):

   ```bash
   cp /path/to/your/terraform.hclic tfe-local-mirror-vmware/files/terraform.hclic
   ```

2. Initialise plugins:

   ```bash
   packer init tfe-local-mirror-vmware
   ```

3. Build the template:

   ```bash
   packer build \
     -var "vcenter_server=vcenter.example.com" \
     -var "vcenter_username=administrator@vsphere.local" \
     -var "vcenter_password=<password>" \
     -var "cluster=ClusterName" \
     -var "datastore=DatastoreName" \
     -var "network=VM Network" \
     tfe-local-mirror-vmware
   ```

   Using a datastore-resident ISO (avoids large download):

   ```bash
   packer build \
     -var "vcenter_server=vcenter.example.com" \
     -var "vcenter_username=administrator@vsphere.local" \
     -var "vcenter_password=<password>" \
     -var "cluster=ClusterName" \
     -var "datastore=DatastoreName" \
     -var "network=VM Network" \
     -var "iso_url=[DatastoreName] ISOs/ubuntu-24.04.4-live-server-amd64.iso" \
     -var "iso_checksum=sha256:e907d92eeec9df64163a7e454cbc8d7755e8ddc7ed42f99dbc80c40f1a138433" \
     tfe-local-mirror-vmware
   ```

---

## Security Notes

- The license file is uploaded to `/tmp/tfe.hclic` on the build VM, used to authenticate to `images.releases.hashicorp.com`, and **deleted** before the template is converted.
- `vcenter_password` and `ssh_password` are declared `sensitive = true` — they are redacted from Packer output.
- The `packer` user password is locked after provisioning; no known credentials remain on the template.
- `*.hclic` is listed in `.gitignore` — do not force-add it.
- The `files/` directory contains only a `.gitkeep`; the actual license file is git-ignored.
