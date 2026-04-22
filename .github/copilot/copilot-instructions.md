# GitHub Copilot Instructions

## Priority Guidelines

When generating code for this repository:

1. **Version Compatibility**: Always respect the exact plugin and tool versions declared in each template's `packer {}` block and in the CI workflow
2. **Context Files**: Prioritize patterns defined in this `.github/copilot` directory
3. **Codebase Patterns**: When context files don't provide specific guidance, replicate patterns from existing templates and scripts
4. **Architectural Consistency**: Maintain the one-directory-per-build structure; never mix source blocks or build blocks from different cloud providers in the same file
5. **Code Quality**: Prioritize consistency, security (credential hygiene), and maintainability in all generated code

---

## Technology Stack

| Layer | Tool / Version |
|---|---|
| Image-build DSL | HashiCorp Packer HCL2 (`.pkr.hcl`) — requires Packer ≥ 1.9 |
| GCP plugin | `hashicorp/googlecompute` ≥ 1.1.1 |
| AWS plugin | `hashicorp/amazon` ≥ 1.2.0 |
| Azure plugin | `hashicorp/azure` ≥ 2.0.0 |
| VMware plugin | `hashicorp/vsphere` ≥ 1.2.0 |
| Provisioner language | Bash (POSIX `#!/usr/bin/env bash`, `set -euo pipefail`) |
| Task runner | Taskfile v3 (`Taskfile.yml`) |
| CI/CD | GitHub Actions — `hashicorp/setup-packer@main`, `version: latest` |
| Base OS | Ubuntu 24.04 LTS (`ubuntu-2404-lts-amd64` / `ubuntu-noble-24.04`) |

Never introduce a plugin version lower than the minimums above or use Packer JSON template syntax (`.json`).

---

## Repository Structure

Every build lives in its own self-contained directory:

```
<cloud>-<purpose>/
├── main.pkr.hcl          # packer{} block, source block, build block
├── variables.pkr.hcl     # all variable declarations
├── scripts/              # shell provisioner scripts (optional, for complex setups)
│   └── setup-<purpose>.sh
├── files/                # static files uploaded to the build VM (optional)
│   └── .gitkeep
├── http/                 # cloud-init / autoinstall seed files (VMware only)
└── README.md
```

Shared provisioner scripts that are reused across multiple builds live in the root-level `scripts/` directory. A build that needs a shared script references it as `${path.root}/../scripts/<script>.sh`.

---

## HCL Template Patterns

### `main.pkr.hcl`

Always use this file structure in this order:

1. `packer {}` block declaring `required_plugins`
2. `locals {}` block (omit if no locals needed)
3. `source "<builder-type>" "<build-name>" {}` block
4. `build {}` block

```hcl
packer {
  required_plugins {
    googlecompute = {
      version = ">= 1.1.1"
      source  = "github.com/hashicorp/googlecompute"
    }
  }
}

source "googlecompute" "<build-name>" {
  project_id          = var.project_id
  source_image_family = "ubuntu-2404-lts-amd64"
  zone                = var.zone
  machine_type        = var.machine_type
  image_name          = "${var.image_name}-{{timestamp}}"
  image_family        = var.image_family
  image_description   = "<descriptive sentence>"
  ssh_username        = "packer"
  tags                = ["packer"]
  disk_size           = var.disk_size
  disk_type           = "pd-ssd"
}

build {
  name    = "<build-name>"
  sources = ["source.googlecompute.<build-name>"]

  provisioner "shell" {
    # inline for simple commands; scripts for complex setups
  }
}
```

**Key rules:**
- `image_name` always appends `{{timestamp}}` via HCL interpolation: `"${var.image_name}-{{timestamp}}"`
- `source` block name and `build` block `name` both match the directory name (kebab-case)
- GCP: `ssh_username = "packer"`, `tags = ["packer"]`, `disk_type = "pd-ssd"`
- AWS: `ssh_username = "ubuntu"`, use `source_ami_filter` with `most_recent = true`, EBS volume type `gp3`
- Azure: `ssh_username = "packer"`, always include a final `waagent -deprovision+user` provisioner shell step to generalise the image
- VMware: use `vsphere-iso`, `cd_files`/`cd_label = "cidata"` for autoinstall seed; lock the packer account password in a final provisioner step

### Path resolution local

When a variable holds a file path that may be relative or absolute, resolve it with a `locals` block using this exact pattern (do not deviate from it):

```hcl
locals {
  resolved_<var>_file = (
    substr(var.<var>_file, 0, 1) == "/" ?
    var.<var>_file :
    "${path.root}/${var.<var>_file}"
  )
}
```

### `provisioner "file"` for sensitive uploads

License files or other sensitive files are uploaded to `/tmp/` and must be deleted by the provisioner script before the image is captured:

```hcl
provisioner "file" {
  source      = local.resolved_tfe_license_file
  destination = "/tmp/tfe.hclic"
}
```

### Passing variables to shell provisioners

Use `environment_vars` — never inline secret values:

```hcl
provisioner "shell" {
  environment_vars = [
    "SOME_VAR=${var.some_var}",
  ]
  scripts = ["${path.root}/scripts/setup-<purpose>.sh"]
}
```

---

## `variables.pkr.hcl` Patterns

Every variable must have `type`, `description`, and `default` (omit `default` only when a value is genuinely required and has no safe default).

```hcl
variable "project_id" {
  type        = string
  description = "The GCP project ID where the image will be built."
}

variable "zone" {
  type        = string
  description = "The GCP zone where the build instance will run."
  default     = "us-central1-a"
}

variable "disk_size" {
  type        = number
  description = "The size of the boot disk in GB."
  default     = 20
}
```

Use `sensitive = true` for passwords and credential variables:

```hcl
variable "vcenter_password" {
  type        = string
  sensitive   = true
  description = "vCenter password. Mark as sensitive — never commit a value to source control."
}
```

**Standard variable names by cloud provider:**

| Purpose | GCP | AWS | Azure | VMware |
|---|---|---|---|---|
| Project/account | `project_id` | (implicit via AWS credentials) | `subscription_id` | `vcenter_server` |
| Region/zone | `zone` | `region` | `location` | `datacenter` / `cluster` |
| Instance size | `machine_type` | `instance_type` | `vm_size` | `cpus` + `ram_mb` |
| Output image name | `image_name` / `image_family` | `ami_name` | `image_name` | `vm_name` |
| Disk size | `disk_size` | `disk_size` | `disk_size` | `disk_size` |

---

## Shell Script Patterns

All provisioner scripts follow this structure:

```bash
#!/usr/bin/env bash
# <script-filename>
# <One-line summary of what the script does.>
# <Additional detail if needed.>
#
# Required environment variables (set by Packer):
#   VAR_NAME  — description

set -euo pipefail

# ---------------------------------------------------------------------------
# Section heading
# ---------------------------------------------------------------------------
echo "==> Section description..."
```

**Rules:**
- First line: `#!/usr/bin/env bash`
- Second line: `# <filename>` (matches the actual file name)
- Header comment block documents purpose and required env vars
- `set -euo pipefail` immediately after the header
- All log output uses `echo "==> ..."` for major steps and `echo "  ..."` for sub-steps
- Section separators use `# ---...---` (74 dashes) with a blank line before and after
- Always wait for cloud-init at the start: `sudo cloud-init status --wait || true`
- Always use `DEBIAN_FRONTEND=noninteractive` for apt installs
- Docker CE installation always follows the official keyring method (see existing scripts)
- Readiness polling uses `for i in $(seq 1 30); do ... sleep 2; done`
- systemd unit files are embedded via heredoc with single-quoted delimiter (`<< 'SERVICE'`) to prevent variable expansion
- Sensitive credentials are always removed before script exits:
  - `sudo rm -f /tmp/tfe.hclic`
  - `sudo docker logout <registry>`
  - `sudo rm -f /root/.docker/config.json`

---

## Security Patterns

- **Never commit** `*.pkrvars.hcl`, `*.hclic`, `*.tfvars` files (all git-ignored)
- License files (`*.hclic`) are uploaded to `/tmp/` and deleted by the provisioner script
- Docker registry credentials are always cleaned up (`docker logout` + remove `config.json`)
- VMware builds lock the packer build account after provisioning: `sudo passwd -l packer`
- Azure builds run `waagent -deprovision+user` to remove credentials from the generalised image
- Sensitive Packer variables use `sensitive = true`
- CI secrets (`GCP_CREDENTIALS`) are referenced only via `${{ secrets.* }}`; plaintext values are never hardcoded in workflow YAML

---

## CI/CD Patterns (GitHub Actions)

- Workflow file lives at `.github/workflows/validate.yml`
- Three jobs always present: `fmt`, `validate`, `shellcheck`
- Packer setup: `uses: hashicorp/setup-packer@main` with `version: latest`
- Format check: `packer fmt -check -recursive "<dir>"`
- Validate: `packer init "<dir>"` then `packer validate <vars> "<dir>"`
- Shell linting: `uses: ludeeus/action-shellcheck@master` with `severity: warning`
- Matrix strategy with `fail-fast: false` for validate job
- Placeholder values are used for required variables in CI (e.g., `project_id=placeholder-project-id`) so `packer validate` can complete without real credentials
- Placeholder license files are created at `<dir>/files/terraform.hclic` when needed: `echo "placeholder" > ...`

---

## Taskfile Patterns

Tasks are namespaced `packer:<verb>` or `packer:<verb>:one`. Bulk operations iterate over `{{.TEMPLATE_DIRS}}` (auto-discovered via `find`). Per-directory operations require a `TEMPLATE` variable.

When adding a new task:
- Follow the existing `packer:<verb>` naming scheme
- Add a `desc:` field
- Use `requires: vars: [TEMPLATE]` for single-template tasks
- Pass optional extra args via a `*_ARGS` variable (e.g., `{{.BUILD_ARGS}}`)

---

## Naming Conventions

| Artifact | Convention | Example |
|---|---|---|
| Build directory | kebab-case: `<cloud>-<purpose>` | `tfe-local-mirror-aws` |
| Source block name | matches directory name | `"tfe-local-mirror"` |
| Build block `name` | matches directory name | `"tfe-local-mirror-aws"` |
| Shell script | `setup-<purpose>.sh` | `setup-tfe-mirror.sh` |
| Variable names | snake_case | `tfe_license_file` |
| Image/AMI name variable | `image_name` (GCP/Azure), `ami_name` (AWS), `vm_name` (VMware) | — |
| Timestamp suffix | Always `{{timestamp}}` in HCL interpolation | `"${var.image_name}-{{timestamp}}"` |

---

## Adding a New Build

When creating a new Packer build template directory:

1. Create a new directory: `<cloud>-<purpose>/`
2. Create `main.pkr.hcl` with the `packer {}`, `source`, and `build` blocks following the patterns above
3. Create `variables.pkr.hcl` with all variable declarations (type + description + default)
4. Create `scripts/setup-<purpose>.sh` if provisioning is non-trivial (follow the shell script pattern above)
5. Create `files/.gitkeep` if the build uploads files
6. Add the new directory to the `fmt` job in `.github/workflows/validate.yml`
7. Add a matrix entry to the `validate` job in `.github/workflows/validate.yml`
8. Update the root `README.md` Builds table
9. Create a `README.md` in the new directory following the same structure as existing ones

---

## General Best Practices

- Scan existing templates before writing new ones; replicate the closest matching pattern
- Never use Packer JSON syntax; always use HCL2 (`.pkr.hcl`)
- Prefer `scripts = [...]` over `inline = [...]` for anything beyond a handful of commands
- Never hardcode project IDs, credentials, or region values in template files
- Keep `variables.pkr.hcl` and `main.pkr.hcl` as the only `.pkr.hcl` files per directory
- Match the line-ending rules in `.gitattributes`: HCL, shell, YAML, and Markdown files must use LF
- When in doubt, prioritise consistency with existing templates over external best practices
