locals {
  name = var.name
  desired = coalesce(var.desired_capacity, var.min_size)

  common_tags = merge(
    { Module = "ubuntu-docker-mirror-aws", ManagedBy = "terraform" },
    var.tags
  )
}

# ── AMI lookup ─────────────────────────────────────────────────────────────────
data "aws_ami" "mirror" {
  most_recent = true
  owners      = var.ami_owners

  filter {
    name   = "name"
    values = [var.ami_name_filter]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# ── Security groups ─────────────────────────────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${local.name}-alb"
  description = "Allow inbound HTTP/HTTPS to the ALB"
  vpc_id      = var.vpc_id
  tags        = merge(local.common_tags, { Name = "${local.name}-alb" })
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "HTTP from anywhere"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  count             = var.certificate_arn != "" ? 1 : 0
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS from anywhere"
}

resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound"
}

resource "aws_security_group" "instances" {
  name        = "${local.name}-instances"
  description = "Allow registry traffic from ALB; deny direct internet access"
  vpc_id      = var.vpc_id
  tags        = merge(local.common_tags, { Name = "${local.name}-instances" })
}

resource "aws_vpc_security_group_ingress_rule" "instances_registry" {
  security_group_id            = aws_security_group.instances.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.registry_port
  to_port                      = var.registry_port
  ip_protocol                  = "tcp"
  description                  = "Registry traffic from ALB"
}

resource "aws_vpc_security_group_ingress_rule" "instances_ssh" {
  count             = var.key_name != "" ? 1 : 0
  security_group_id = aws_security_group.instances.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  description       = "SSH (restrict to bastion CIDR in production)"
}

resource "aws_vpc_security_group_egress_rule" "instances_all" {
  security_group_id = aws_security_group.instances.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound (Docker Hub pull-through cache)"
}

# ── IAM instance profile ────────────────────────────────────────────────────────
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name               = "${local.name}-instance"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "instance" {
  name = "${local.name}-instance"
  role = aws_iam_role.instance.name
  tags = local.common_tags
}

# ── Launch template ─────────────────────────────────────────────────────────────
resource "aws_launch_template" "mirror" {
  name_prefix   = "${local.name}-"
  image_id      = data.aws_ami.mirror.id
  instance_type = var.instance_type
  key_name      = var.key_name != "" ? var.key_name : null

  iam_instance_profile {
    name = aws_iam_instance_profile.instance.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.instances.id]
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = var.root_volume_size_gb
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = local.name })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = local.common_tags
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}

# ── Application Load Balancer ───────────────────────────────────────────────────
resource "aws_lb" "mirror" {
  name               = local.name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = merge(local.common_tags, { Name = local.name })
}

resource "aws_lb_target_group" "mirror" {
  name        = local.name
  port        = var.registry_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 10
    matcher             = "200-399"
  }

  tags = merge(local.common_tags, { Name = local.name })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.mirror.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = var.certificate_arn != "" ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = var.certificate_arn != "" ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    dynamic "forward" {
      for_each = var.certificate_arn == "" ? [1] : []
      content {
        target_group {
          arn = aws_lb_target_group.mirror.arn
        }
      }
    }
  }
}

resource "aws_lb_listener" "https" {
  count             = var.certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.mirror.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mirror.arn
  }
}

# ── Auto Scaling Group ──────────────────────────────────────────────────────────
resource "aws_autoscaling_group" "mirror" {
  name                = local.name
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [aws_lb_target_group.mirror.arn]

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = local.desired

  health_check_type         = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.mirror.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  dynamic "tag" {
    for_each = merge(local.common_tags, { Name = local.name })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

# ── Scaling policies ────────────────────────────────────────────────────────────
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${local.name}-scale-out"
  autoscaling_group_name = aws_autoscaling_group.mirror.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 120
}

resource "aws_autoscaling_policy" "scale_in" {
  name                   = "${local.name}-scale-in"
  autoscaling_group_name = aws_autoscaling_group.mirror.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${local.name}-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.scale_out_cpu_threshold
  alarm_description   = "Scale out when average CPU >= ${var.scale_out_cpu_threshold}%"
  alarm_actions       = [aws_autoscaling_policy.scale_out.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.mirror.name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${local.name}-cpu-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 5
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.scale_in_cpu_threshold
  alarm_description   = "Scale in when average CPU <= ${var.scale_in_cpu_threshold}%"
  alarm_actions       = [aws_autoscaling_policy.scale_in.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.mirror.name
  }

  tags = local.common_tags
}

# ── Route 53 DNS ────────────────────────────────────────────────────────────────
resource "aws_route53_record" "mirror" {
  zone_id = var.route53_zone_id
  name    = var.dns_name
  type    = "A"

  alias {
    name                   = aws_lb.mirror.dns_name
    zone_id                = aws_lb.mirror.zone_id
    evaluate_target_health = true
  }
}
