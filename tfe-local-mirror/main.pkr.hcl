packer {
  required_plugins {
    googlecompute = {
      version = ">= 1.1.1"
      source  = "github.com/hashicorp/googlecompute"
    }
  }
}

source "googlecompute" "tfe-local-mirror" {
  project_id          = var.project_id
  source_image_family = "ubuntu-2404-lts-amd64"
  zone                = var.zone
  machine_type        = var.machine_type
  image_name          = "${var.image_name}-{{timestamp}}"
  image_family        = var.image_family
  image_description   = "Ubuntu 24.04 LTS with Terraform Enterprise ${var.tfe_version} pre-loaded into a local Docker registry"
  ssh_username        = "packer"
  tags                = ["packer"]
  disk_size           = var.disk_size
  disk_type           = "pd-ssd"
}

build {
  name    = "tfe-local-mirror"
  sources = ["source.googlecompute.tfe-local-mirror"]

  # Upload the license file to a temporary location on the build VM.
  # It is used only for docker login and is deleted by the script before the image is finalised.
  provisioner "file" {
    source      = var.tfe_license_file
    destination = "/tmp/tfe.hclic"
  }

  provisioner "shell" {
    environment_vars = [
      "TFE_VERSION=${var.tfe_version}",
    ]
    scripts = ["${path.root}/scripts/setup-tfe-mirror.sh"]
  }
}
