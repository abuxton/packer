packer {
  required_plugins {
    googlecompute = {
      version = ">= 1.1.1"
      source  = "github.com/hashicorp/googlecompute"
    }
  }
}

source "googlecompute" "ubuntu-docker-local-container" {
  project_id          = var.project_id
  source_image_family = "ubuntu-2404-lts-amd64"
  zone                = var.zone
  machine_type        = var.machine_type
  image_name          = "${var.image_name}-{{timestamp}}"
  image_family        = var.image_family
  image_description   = "Ubuntu 24.04 LTS with a pre-loaded container image served from a local Docker registry"
  ssh_username        = "packer"
  tags                = ["packer"]
  disk_size           = var.disk_size
  disk_type           = "pd-ssd"
}

build {
  name    = "ubuntu-docker-local-container"
  sources = ["source.googlecompute.ubuntu-docker-local-container"]

  provisioner "shell" {
    environment_vars = ["CONTAINER_IMAGE=${var.container_image}"]
    scripts          = ["${path.root}/scripts/setup-docker-local.sh"]
  }
}
