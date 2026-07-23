# Application Load Balancer: the single public entry point. Instances are
# registered by the Auto Scaling Group rather than listed here, so scaling
# events wire themselves up without a Terraform run.

resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.security_group_id]
  subnets            = var.subnet_ids

  # Guards against `terraform destroy` quietly taking the site down while
  # someone is looking at it. Flip to true in the variable to tear down.
  enable_deletion_protection = var.enable_deletion_protection

  # Long enough to outlast a slow client, short enough to release sockets.
  idle_timeout = var.idle_timeout

  # Without this, a request for a path containing an encoded slash is rejected
  # or ambiguous. Dropping invalid headers is the safer default.
  drop_invalid_header_fields = true

  enable_http2 = true

  dynamic "access_logs" {
    for_each = var.access_logs_bucket == null ? [] : [1]

    content {
      bucket  = var.access_logs_bucket
      prefix  = var.name
      enabled = true
    }
  }

  tags = {
    Name = "${var.name}-alb"
  }
}

resource "aws_lb_target_group" "this" {
  name     = "${var.name}-tg"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  # Instance targets, since the ASG registers EC2 instances directly.
  target_type = "instance"

  health_check {
    enabled = true
    path    = var.health_check_path

    # Two consecutive passes to come into service, so a host that flaps does
    # not start taking traffic prematurely.
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
    protocol            = "HTTP"
    port                = "traffic-port"
  }

  # Time the ALB waits for in-flight requests before removing a target. Static
  # responses finish fast, so a long drain only slows deployments down.
  deregistration_delay = var.deregistration_delay

  stickiness {
    enabled = false
    type    = "lb_cookie"
  }

  tags = {
    Name = "${var.name}-tg"
  }

  # The listener references this group, so a replacement must exist first.
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  tags = {
    Name = "${var.name}-http-listener"
  }
}
