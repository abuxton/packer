terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "docker_mirror" {
  source = "../../"

  project_id       = var.project_id
  region           = var.region
  subnetwork       = var.subnetwork
  dns_managed_zone = var.dns_managed_zone
  dns_name         = var.dns_name

  machine_type  = "e2-standard-2"
  min_replicas  = 2
  max_replicas  = 4

  labels = { environment = "example" }
}
