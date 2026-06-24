# Tests for the ubuntu-docker-mirror GCP module
#
# Run with:  terraform test  (Terraform >= 1.6)
#
# These tests validate plan-time behaviour without requiring real GCP credentials.

variables {
  project_id       = "test-project-123456"
  subnetwork       = "projects/test-project-123456/regions/us-central1/subnetworks/default"
  dns_managed_zone = "example-zone"
  dns_name         = "mirror.example.com."
}

# ── Validate default variable values ───────────────────────────────────────────
run "defaults_are_sane" {
  command = plan

  assert {
    condition     = var.machine_type == "e2-standard-2"
    error_message = "Default machine_type should be e2-standard-2"
  }

  assert {
    condition     = var.min_replicas == 2
    error_message = "Default min_replicas should be 2"
  }

  assert {
    condition     = var.max_replicas == 6
    error_message = "Default max_replicas should be 6"
  }

  assert {
    condition     = var.registry_port == 5000
    error_message = "Default registry_port should be 5000"
  }

  assert {
    condition     = var.boot_disk_size_gb == 50
    error_message = "Default boot_disk_size_gb should be 50"
  }

  assert {
    condition     = var.boot_disk_type == "pd-ssd"
    error_message = "Default boot_disk_type should be pd-ssd"
  }
}

# ── Validate image family default ──────────────────────────────────────────────
run "image_family_default" {
  command = plan

  assert {
    condition     = var.image_family == "ubuntu-docker-mirror"
    error_message = "Default image_family should be ubuntu-docker-mirror"
  }
}

# ── Validate autoscaler CPU target ─────────────────────────────────────────────
run "autoscaler_cpu_target_default" {
  command = plan

  assert {
    condition     = var.scale_out_cpu_target == 0.7
    error_message = "Default scale_out_cpu_target should be 0.7"
  }
}

# ── Validate DNS record uses correct name ───────────────────────────────────────
run "dns_record_matches_variable" {
  command = plan

  variables {
    dns_name = "custom.example.com."
  }

  assert {
    condition     = google_dns_record_set.mirror.name == "custom.example.com."
    error_message = "DNS record name should match var.dns_name"
  }
}

# ── Validate MIG region matches variable ───────────────────────────────────────
run "mig_region_matches_variable" {
  command = plan

  variables {
    region = "europe-west1"
  }

  assert {
    condition     = google_compute_region_instance_group_manager.mirror.region == "europe-west1"
    error_message = "MIG region should match var.region"
  }
}

# ── Validate network tags are applied ─────────────────────────────────────────
run "network_tags_applied" {
  command = plan

  assert {
    condition     = contains(google_compute_instance_template.mirror.tags, "docker-mirror")
    error_message = "Instance template should include the docker-mirror network tag"
  }
}
