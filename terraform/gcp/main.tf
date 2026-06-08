locals {
  name              = var.name
  image_project     = coalesce(var.image_project, var.project_id)
  subnetwork_project = coalesce(var.subnetwork_project, var.project_id)

  common_labels = merge(
    { module = "ubuntu-docker-mirror-gcp", managed-by = "terraform" },
    var.labels
  )
}

# ── Image lookup ────────────────────────────────────────────────────────────────
data "google_compute_image" "mirror" {
  family  = var.image_family
  project = local.image_project
}

# ── Firewall rules ──────────────────────────────────────────────────────────────
data "google_compute_subnetwork" "mirror" {
  self_link = var.subnetwork
  project   = local.subnetwork_project
}

resource "google_compute_firewall" "allow_lb_to_registry" {
  name    = "${local.name}-allow-lb"
  project = var.project_id
  network = data.google_compute_subnetwork.mirror.network

  description = "Allow Google Cloud load balancer health checks and traffic to the Docker Registry port"

  allow {
    protocol = "tcp"
    ports    = [tostring(var.registry_port)]
  }

  # GCP load balancer health check source ranges
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = var.tags
}

# ── Instance template ───────────────────────────────────────────────────────────
resource "google_compute_instance_template" "mirror" {
  name_prefix  = "${local.name}-"
  project      = var.project_id
  machine_type = var.machine_type
  region       = var.region
  tags         = var.tags
  labels       = local.common_labels

  disk {
    source_image = data.google_compute_image.mirror.self_link
    auto_delete  = true
    boot         = true
    disk_type    = var.boot_disk_type
    disk_size_gb = var.boot_disk_size_gb
    disk_encryption_key {}
  }

  network_interface {
    subnetwork         = var.subnetwork
    subnetwork_project = local.subnetwork_project
    # No external IP — instances access Docker Hub via Cloud NAT
  }

  dynamic "service_account" {
    for_each = var.service_account_email != "" ? [var.service_account_email] : []
    content {
      email  = service_account.value
      scopes = ["cloud-platform"]
    }
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ── Regional Managed Instance Group ────────────────────────────────────────────
resource "google_compute_region_instance_group_manager" "mirror" {
  name               = local.name
  project            = var.project_id
  region             = var.region
  base_instance_name = local.name

  version {
    instance_template = google_compute_instance_template.mirror.self_link
  }

  named_port {
    name = "registry"
    port = var.registry_port
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.registry.self_link
    initial_delay_sec = 120
  }

  update_policy {
    type                         = "PROACTIVE"
    minimal_action               = "REPLACE"
    max_surge_fixed              = 2
    max_unavailable_fixed        = 0
    replacement_method           = "SUBSTITUTE"
  }

  lifecycle {
    ignore_changes = [target_size]
  }
}

# ── Autoscaler ──────────────────────────────────────────────────────────────────
resource "google_compute_region_autoscaler" "mirror" {
  name    = local.name
  project = var.project_id
  region  = var.region
  target  = google_compute_region_instance_group_manager.mirror.self_link

  autoscaling_policy {
    min_replicas    = var.min_replicas
    max_replicas    = var.max_replicas
    cooldown_period = 120

    cpu_utilization {
      target = var.scale_out_cpu_target
    }
  }
}

# ── Health check ────────────────────────────────────────────────────────────────
resource "google_compute_health_check" "registry" {
  name    = "${local.name}-registry"
  project = var.project_id

  check_interval_sec  = 15
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = var.registry_port
    request_path = "/"
  }
}

# ── HTTP Load Balancer ──────────────────────────────────────────────────────────
resource "google_compute_global_address" "mirror" {
  name    = "${local.name}-ip"
  project = var.project_id
}

resource "google_compute_backend_service" "mirror" {
  name                  = local.name
  project               = var.project_id
  protocol              = "HTTP"
  port_name             = "registry"
  load_balancing_scheme = "EXTERNAL"
  timeout_sec           = 30

  health_checks = [google_compute_health_check.registry.self_link]

  backend {
    group           = google_compute_region_instance_group_manager.mirror.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

resource "google_compute_url_map" "mirror" {
  name            = local.name
  project         = var.project_id
  default_service = google_compute_backend_service.mirror.self_link
}

resource "google_compute_target_http_proxy" "mirror" {
  name    = local.name
  project = var.project_id
  url_map = google_compute_url_map.mirror.self_link
}

resource "google_compute_global_forwarding_rule" "mirror" {
  name                  = local.name
  project               = var.project_id
  ip_address            = google_compute_global_address.mirror.address
  port_range            = "80"
  target                = google_compute_target_http_proxy.mirror.self_link
  load_balancing_scheme = "EXTERNAL"
}

# ── Cloud DNS record ────────────────────────────────────────────────────────────
resource "google_dns_record_set" "mirror" {
  name         = var.dns_name
  managed_zone = var.dns_managed_zone
  project      = var.project_id
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.mirror.address]
}
