# Tests for the ubuntu-docker-mirror AWS module
#
# Run with:  terraform test  (Terraform >= 1.6)
#
# These tests validate the module's plan output and variable defaults without
# requiring real AWS credentials.  Set TF_VAR_* environment variables or a
# .tfvars file to run apply-mode tests against a real account.

variables {
  vpc_id             = "vpc-00000000000000001"
  public_subnet_ids  = ["subnet-pub-a00000001", "subnet-pub-b00000002"]
  private_subnet_ids = ["subnet-priv-a00000001", "subnet-priv-b00000002"]
  route53_zone_id    = "Z00000000000000000001"
  dns_name           = "mirror.test.example.com"
}

# ── Validate default variable values ───────────────────────────────────────────
run "defaults_are_sane" {
  command = plan

  assert {
    condition     = var.instance_type == "t3.medium"
    error_message = "Default instance_type should be t3.medium"
  }

  assert {
    condition     = var.min_size == 2
    error_message = "Default min_size should be 2"
  }

  assert {
    condition     = var.max_size == 6
    error_message = "Default max_size should be 6"
  }

  assert {
    condition     = var.registry_port == 5000
    error_message = "Default registry_port should be 5000"
  }

  assert {
    condition     = var.root_volume_size_gb == 50
    error_message = "Default root_volume_size_gb should be 50"
  }
}

# ── Validate ASG sizing logic ───────────────────────────────────────────────────
run "asg_desired_defaults_to_min_size" {
  command = plan

  variables {
    min_size         = 3
    desired_capacity = null
  }

  assert {
    condition     = aws_autoscaling_group.mirror.desired_capacity == 3
    error_message = "desired_capacity should default to min_size when not set"
  }
}

# ── Validate HTTPS listener created only when cert is provided ──────────────────
run "https_listener_absent_without_cert" {
  command = plan

  assert {
    condition     = length(aws_lb_listener.https) == 0
    error_message = "HTTPS listener should not be created when certificate_arn is empty"
  }
}

run "https_listener_present_with_cert" {
  command = plan

  variables {
    certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  }

  assert {
    condition     = length(aws_lb_listener.https) == 1
    error_message = "HTTPS listener should be created when certificate_arn is set"
  }
}

# ── Validate SSH security group rule absent when no key_name ────────────────────
run "ssh_rule_absent_without_key" {
  command = plan

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.instances_ssh) == 0
    error_message = "SSH ingress rule should not be created when key_name is empty"
  }
}
