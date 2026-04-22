packer {
  required_plugins {
    googlecompute = {
      version = ">= 1.1.1"
      source  = "github.com/hashicorp/googlecompute"
    }
  }
}

source "googlecompute" "ubuntu-docker-mirror" {
  project_id          = var.project_id
  source_image_family = "ubuntu-2404-lts-amd64"
  zone                = var.zone
  machine_type        = var.machine_type
  image_name          = "${var.image_name}-{{timestamp}}"
  image_family        = var.image_family
  image_description   = "Ubuntu 24.04 LTS with local Docker registry pull-through cache mirror"
  ssh_username        = "packer"
  tags                = ["packer"]
  disk_size           = var.disk_size
  disk_type           = "pd-ssd"
}

build {
  name    = "ubuntu-docker-mirror"
  sources = ["source.googlecompute.ubuntu-docker-mirror"]

  provisioner "shell" {
    scripts = ["${path.root}/scripts/setup-docker-mirror.sh"]
  }
}
