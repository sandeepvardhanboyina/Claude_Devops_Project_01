# Auto Scaling Group and its CloudWatch alarms.
#
# Scaling uses simple step policies driven by explicit CPU alarms rather than a
# target-tracking policy, because the assignment calls for visible thresholds at
# 70% and 30% and because the alarm objects themselves are the deliverable.

resource "aws_autoscaling_group" "this" {
  name = "${var.name}-asg"

  min_size         = var.min_size
  desired_capacity = var.desired_capacity
  max_size         = var.max_size

  vpc_zone_identifier = var.subnet_ids
  target_group_arns   = [var.target_group_arn]

  # ELB rather than EC2: an instance whose nginx has died still passes its EC2
  # status checks, so only the load balancer's view catches a broken web server.
  health_check_type = "ELB"

  # Bootstrap installs packages and the CloudWatch agent; give it time to finish
  # before the first health check counts against the instance.
  health_check_grace_period = var.health_check_grace_period

  default_cooldown          = var.cooldown
  wait_for_capacity_timeout = "10m"

  launch_template {
    id      = var.launch_template_id
    version = var.launch_template_version
  }

  # Roll instances automatically when the launch template changes, keeping most
  # of the fleet in service throughout.
  dynamic "instance_refresh" {
    for_each = var.enable_instance_refresh ? [1] : []

    content {
      strategy = "Rolling"

      preferences {
        min_healthy_percentage = 50
        instance_warmup        = tostring(var.health_check_grace_period)
      }
    }
  }

  # Spread instances evenly across AZs so losing one zone costs half the
  # capacity rather than all of it.
  availability_zone_distribution {
    capacity_distribution_strategy = "balanced-best-effort"
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-web"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.additional_tags

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true

    # Capacity drifts as scaling policies act; adopting that drift on the next
    # apply would undo whatever scaling had just happened.
    ignore_changes = [desired_capacity]
  }
}

# ---------------------------------------------------------------------------
# Scale out — CPU above 70%
# ---------------------------------------------------------------------------

resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${var.name}-scale-out"
  autoscaling_group_name = aws_autoscaling_group.this.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = var.scale_out_adjustment
  cooldown               = var.cooldown
  policy_type            = "SimpleScaling"
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name        = "${var.name}-cpu-high"
  alarm_description = "Average CPU above ${var.scale_out_threshold}% — add capacity"

  namespace   = "AWS/EC2"
  metric_name = "CPUUtilization"
  statistic   = "Average"

  comparison_operator = "GreaterThanThreshold"
  threshold           = var.scale_out_threshold
  period              = var.alarm_period
  evaluation_periods  = var.scale_out_evaluation_periods

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.this.name
  }

  alarm_actions = concat(
    [aws_autoscaling_policy.scale_out.arn],
    var.alarm_notification_arns,
  )

  # Missing data during a scaling event should not read as a breach.
  treat_missing_data = "notBreaching"

  tags = {
    Name = "${var.name}-cpu-high"
  }
}

# ---------------------------------------------------------------------------
# Scale in — CPU below 30%
# ---------------------------------------------------------------------------

resource "aws_autoscaling_policy" "scale_in" {
  name                   = "${var.name}-scale-in"
  autoscaling_group_name = aws_autoscaling_group.this.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = var.scale_in_adjustment
  cooldown               = var.cooldown
  policy_type            = "SimpleScaling"
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name        = "${var.name}-cpu-low"
  alarm_description = "Average CPU below ${var.scale_in_threshold}% — remove capacity"

  namespace   = "AWS/EC2"
  metric_name = "CPUUtilization"
  statistic   = "Average"

  comparison_operator = "LessThanThreshold"
  threshold           = var.scale_in_threshold
  period              = var.alarm_period

  # Slower to scale in than out: shedding capacity too eagerly causes
  # thrashing, and being briefly over-provisioned is cheaper than being short.
  evaluation_periods = var.scale_in_evaluation_periods

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.this.name
  }

  alarm_actions      = [aws_autoscaling_policy.scale_in.arn]
  treat_missing_data = "notBreaching"

  tags = {
    Name = "${var.name}-cpu-low"
  }
}

# ---------------------------------------------------------------------------
# Alert-only alarms — no scaling action
# ---------------------------------------------------------------------------

# Sustained CPU above 80% means scaling out is not keeping up, usually because
# the group is already at max_size.
resource "aws_cloudwatch_metric_alarm" "cpu_critical" {
  alarm_name        = "${var.name}-cpu-critical"
  alarm_description = "Average CPU above ${var.critical_cpu_threshold}% — capacity is not keeping up with demand"

  namespace   = "AWS/EC2"
  metric_name = "CPUUtilization"
  statistic   = "Average"

  comparison_operator = "GreaterThanThreshold"
  threshold           = var.critical_cpu_threshold
  period              = var.alarm_period
  evaluation_periods  = 2

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.this.name
  }

  alarm_actions      = var.alarm_notification_arns
  ok_actions         = var.alarm_notification_arns
  treat_missing_data = "notBreaching"

  tags = {
    Name = "${var.name}-cpu-critical"
  }
}

# Memory comes from the CloudWatch agent, not the hypervisor, so this alarm
# only works when the launch template installed the agent.
resource "aws_cloudwatch_metric_alarm" "memory_high" {
  count = var.enable_memory_alarm ? 1 : 0

  alarm_name        = "${var.name}-memory-high"
  alarm_description = "Average memory above ${var.memory_threshold}% as reported by the CloudWatch agent"

  namespace   = var.metrics_namespace
  metric_name = "MemoryUtilization"
  statistic   = "Average"

  comparison_operator = "GreaterThanThreshold"
  threshold           = var.memory_threshold
  period              = var.alarm_period
  evaluation_periods  = 2

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.this.name
  }

  alarm_actions = var.alarm_notification_arns

  # "missing" rather than "notBreaching": if the agent stops reporting, that is
  # a fact worth surfacing, not something to paper over as healthy.
  treat_missing_data = "missing"

  tags = {
    Name = "${var.name}-memory-high"
  }
}

# Any unhealthy target means the ALB has taken a host out of rotation.
#
# The count is gated on a static boolean, not on whether the ARN suffix is null.
# The suffix comes from the ALB module and is unknown until apply, and Terraform
# cannot decide how many resources to create from a value it does not yet know.
resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  count = var.enable_unhealthy_host_alarm ? 1 : 0

  alarm_name        = "${var.name}-unhealthy-hosts"
  alarm_description = "One or more targets are failing the load balancer health check"

  namespace   = "AWS/ApplicationELB"
  metric_name = "UnHealthyHostCount"
  statistic   = "Maximum"

  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  period              = 60
  evaluation_periods  = 2

  dimensions = {
    TargetGroup  = var.target_group_arn_suffix
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions      = var.alarm_notification_arns
  ok_actions         = var.alarm_notification_arns
  treat_missing_data = "notBreaching"

  tags = {
    Name = "${var.name}-unhealthy-hosts"
  }
}
