packer {
  required_plugins {
    vsphere = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/vsphere"
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

source "vsphere-iso" "tfe-local-mirror" {
  # vCenter connection
  vcenter_server      = var.vcenter_server
  username            = var.vcenter_username
  password            = var.vcenter_password
  insecure_connection = var.insecure_connection
  datacenter          = var.datacenter

  # Build placement
  cluster   = var.cluster
  datastore = var.datastore
  folder    = var.folder

  # VM hardware
  vm_name              = "${var.vm_name}-{{timestamp}}"
  guest_os_type        = "ubuntu64Guest"
  CPUs                 = var.cpus
  RAM                  = var.ram_mb
  disk_controller_type = ["pvscsi"]
  storage {
    disk_size             = var.disk_size
    disk_thin_provisioned = true
  }
  network_adapters {
    network      = var.network
    network_card = "vmxnet3"
  }

  # Ubuntu 24.04 ISO
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  # Seed ISO via cd_files — no HTTP server required.
  # Ubuntu autoinstall detects the cidata label and reads user-data/meta-data.
  cd_files = [
    "${path.root}/http/meta-data",
    "${path.root}/http/user-data",
  ]
  cd_label = "cidata"

  # GRUB boot command: interrupt autoboot, add autoinstall kernel parameter
  boot_wait = "5s"
  boot_command = [
    "<wait>",
    "e",
    "<down><down><down><end>",
    " autoinstall ds=nocloud\\;seedfrom=/cdrom/",
    "<f10>",
  ]

  # SSH communicator — credentials match the identity block in http/user-data
  communicator = "ssh"
  ssh_username = "packer"
  ssh_password = var.ssh_password
  ssh_timeout  = "45m"

  shutdown_command = "sudo shutdown -P now"

  # Convert to template after build
  convert_to_template = true
}

build {
  name    = "tfe-local-mirror-vmware"
  sources = ["source.vsphere-iso.tfe-local-mirror"]

  # Upload the license file to a temporary location on the build VM.
  # It is used only for docker login and is deleted by the script before the template is captured.
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

  # Lock the build account password so no known credentials remain on the template.
  provisioner "shell" {
    inline = [
      "sudo passwd -l packer",
      "sudo rm -f /etc/sudoers.d/packer-build",
    ]
  }
}
