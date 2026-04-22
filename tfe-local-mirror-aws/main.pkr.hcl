packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

locals {
  resolved_tfe_license_file = (
    substr(var.tfe_license_file, 0, 1) == "/" ?
    var.tfe_license_file :
    "${path.root}/${var.tfe_license_file}"
  )
}

source "amazon-ebs" "tfe-local-mirror" {
  region          = var.region
  instance_type   = var.instance_type
  ami_name        = "${var.ami_name}-{{timestamp}}"
  ami_description = "Ubuntu 24.04 LTS with Terraform Enterprise ${var.tfe_version} pre-loaded into a local Docker registry"

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["099720109477"] # Canonical
    most_recent = true
  }

  ssh_username = "ubuntu"

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = var.disk_size
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name       = "${var.ami_name}-{{timestamp}}"
    Packer     = "true"
    TFEVersion = var.tfe_version
  }
}

build {
  name    = "tfe-local-mirror-aws"
  sources = ["source.amazon-ebs.tfe-local-mirror"]

  # Upload the license file to a temporary location on the build instance.
  # It is used only for docker login and is deleted by the script before the AMI is captured.
  provisioner "file" {
    source      = local.resolved_tfe_license_file
    destination = "/tmp/tfe.hclic"
  }

  provisioner "shell" {
    environment_vars = [
      "TFE_VERSION=${var.tfe_version}",
    ]
    scripts = ["${path.root}/../scripts/setup-tfe-mirror.sh"]
  }
}
