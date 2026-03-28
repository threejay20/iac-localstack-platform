# ============================================================
# Compute Module — EC2 Launch Template, Auto Scaling Group,
# Application Load Balancer, and Security Groups.
# Simulated via LocalStack (no real AWS spend).
# ============================================================

# ---------- Security Group: ALB ----------
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-alb-sg" })
}

# ---------- Security Group: Application instances ----------
resource "aws_security_group" "app" {
  name        = "${var.name}-app-sg"
  description = "Security group for application EC2 instances — only allows traffic from ALB"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from ALB only"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All outbound (required for package updates, S3 access)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-app-sg" })
}

# ---------- Application Load Balancer ----------
resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection       = false
  enable_cross_zone_load_balancing = true
  idle_timeout                     = 60

  access_logs {
    bucket  = var.access_log_bucket
    prefix  = "${var.name}-alb"
    enabled = var.enable_access_logs
  }

  tags = merge(var.tags, { Name = "${var.name}-alb" })
}

# ---------- ALB Target Group ----------
resource "aws_lb_target_group" "this" {
  name        = "${var.name}-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  deregistration_delay = 30

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = false
  }

  tags = merge(var.tags, { Name = "${var.name}-tg" })
}

# ---------- ALB Listener — HTTP ----------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

# ---------- IAM Instance Profile ----------
resource "aws_iam_instance_profile" "app" {
  name = "${var.name}-instance-profile"
  role = var.instance_role_name

  tags = var.tags
}

# ---------- Launch Template ----------
resource "aws_launch_template" "app" {
  name_prefix   = "${var.name}-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.app.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.app.name
  }

  # Metadata service v2 only — prevents SSRF attacks against IMDSv1
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = true
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.root_volume_size_gb
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    app_name    = var.name
    app_version = var.app_version
    environment = var.environment
    s3_bucket   = var.config_s3_bucket
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.name}-instance" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(var.tags, { Name = "${var.name}-volume" })
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, { Name = "${var.name}-lt" })
}

# ---------- Auto Scaling Group ----------
resource "aws_autoscaling_group" "app" {
  name                      = "${var.name}-asg"
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  vpc_zone_identifier       = var.private_subnet_ids
  target_group_arns         = [aws_lb_target_group.this.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 60
    }
  }

  # Termination policy — prefer older instances first for rolling updates
  termination_policies = ["OldestInstance", "Default"]

  dynamic "tag" {
    for_each = merge(var.tags, { Name = "${var.name}-asg" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }
}

# ---------- Scale-out policy — CPU ----------
resource "aws_autoscaling_policy" "scale_out_cpu" {
  name                   = "${var.name}-scale-out-cpu"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value     = var.cpu_target_utilization
    disable_scale_in = false
  }
}

# ---------- CloudWatch: High CPU alarm ----------
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Average CPU utilization exceeded 80% for 4 minutes"
  treat_missing_data  = "breaching"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }

  alarm_actions = var.alarm_sns_arns
  ok_actions    = var.alarm_sns_arns

  tags = var.tags
}

# ---------- CloudWatch: ALB 5xx errors ----------
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.name}-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "More than 10 ALB 5xx errors in 1 minute"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.this.arn_suffix
  }

  alarm_actions = var.alarm_sns_arns
  ok_actions    = var.alarm_sns_arns

  tags = var.tags
}
