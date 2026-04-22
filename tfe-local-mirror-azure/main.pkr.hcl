packer {
  required_plugins {
    azure = {
      version = ">= 2.0.0"
      source  = "github.com/hashicorp/azure"
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

source "azure-arm" "tfe-local-mirror" {
  subscription_id                   = var.subscription_id
  managed_image_name                = "${var.image_name}-{{timestamp}}"
  managed_image_resource_group_name = var.resource_group
  location                          = var.location
  vm_size                           = var.vm_size

  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "ubuntu-24_04-lts"
  image_sku       = "server"
  image_version   = "latest"
  os_disk_size_gb = var.disk_size

  ssh_username = "packer"

  azure_tags = {
    Packer     = "true"
    TFEVersion = var.tfe_version
  }
}

build {
  name    = "tfe-local-mirror-azure"
  sources = ["source.azure-arm.tfe-local-mirror"]

  # Upload the license file to a temporary location on the build VM.
  # It is used only for docker login and is deleted by the script before the image is captured.
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

  # Generalise the image (required by Azure before capture)
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    inline = [
      "/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync"
    ]
    inline_shebang = "/bin/sh -x"
  }
}
