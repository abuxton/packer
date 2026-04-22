packer {
  required_plugins {
    googlecompute = {
      version = ">= 1.1.1"
      source  = "github.com/hashicorp/googlecompute"
    }
  }
}

source "googlecompute" "ubuntu" {
  project_id          = var.project_id
  source_image_family = "ubuntu-2404-lts-amd64"
  zone                = var.zone
  machine_type        = var.machine_type
  image_name          = "${var.image_name}-{{timestamp}}"
  image_family        = var.image_family
  image_description   = "Ubuntu 24.04 LTS built with Packer"
  ssh_username        = "packer"
  tags                = ["packer"]
  disk_size           = var.disk_size
  disk_type           = "pd-ssd"
}

build {
  name    = "gcp-ubuntu"
  sources = ["source.googlecompute.ubuntu"]

  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "sudo cloud-init status --wait || true",
      "echo 'Starting system update...'",
      "sudo apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y curl wget unzip git ca-certificates",
      "echo 'System provisioning complete.'",
    ]
  }
}
