# Dev environment: composes the six modules into one running system.
#
# Data flows one way through the outputs — vpc feeds the rest, the security
# groups feed the ALB and instances, the launch template and ALB feed the ASG.
# Terraform derives the order from these references; there is no need to state
# it. This directory is the single place anyone runs plan or apply.

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Pin the AZ list at plan time so a change in AWS's ordering does not force
  # subnets to move.
  availability_zones = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # The web server listens on 80; the ALB forwards to the same port.
  app_port = 80
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

module "vpc" {
  source = "../../modules/vpc"

  name                = var.project_name
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = slice(var.public_subnet_cidrs, 0, var.az_count)
  availability_zones  = local.availability_zones
}

# ---------------------------------------------------------------------------
# Firewall
# ---------------------------------------------------------------------------

module "security_group" {
  source = "../../modules/security-group"

  name             = var.project_name
  vpc_id           = module.vpc.vpc_id
  app_port         = local.app_port
  allowed_ssh_cidr = var.allowed_ssh_cidr
}

# ---------------------------------------------------------------------------
# Permissions
# ---------------------------------------------------------------------------

module "iam" {
  source = "../../modules/iam"

  name = var.project_name

  enable_github_oidc       = var.enable_github_oidc
  github_oidc_provider_arn = var.github_oidc_provider_arn
  github_repository        = var.github_repository
  state_bucket_arn         = var.state_bucket_arn
  state_lock_table_arn     = var.state_lock_table_arn
}

# ---------------------------------------------------------------------------
# Instance blueprint
# ---------------------------------------------------------------------------

module "launch_template" {
  source = "../../modules/launch-template"

  name                  = var.project_name
  instance_type         = var.instance_type
  security_group_id     = module.security_group.instance_security_group_id
  instance_profile_name = module.iam.instance_profile_name
  key_name              = var.key_name
  root_volume_size      = var.root_volume_size
  metrics_namespace     = var.metrics_namespace
}

# ---------------------------------------------------------------------------
# Load balancer
# ---------------------------------------------------------------------------

module "alb" {
  source = "../../modules/alb"

  name              = var.project_name
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.public_subnet_ids
  security_group_id = module.security_group.alb_security_group_id
  app_port          = local.app_port
}

# ---------------------------------------------------------------------------
# Alarm notifications
# ---------------------------------------------------------------------------
# An optional SNS topic so alarms can email someone. Without an address the
# alarms still exist and show state in the console; they just notify nothing.

resource "aws_sns_topic" "alarms" {
  count = var.alarm_email == null ? 0 : 1

  name = "${var.project_name}-alarms"

  tags = {
    Name = "${var.project_name}-alarms"
  }
}

resource "aws_sns_topic_subscription" "alarm_email" {
  count = var.alarm_email == null ? 0 : 1

  topic_arn = aws_sns_topic.alarms[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# ---------------------------------------------------------------------------
# Auto Scaling
# ---------------------------------------------------------------------------

module "autoscaling" {
  source = "../../modules/autoscaling"

  name               = var.project_name
  subnet_ids         = module.vpc.public_subnet_ids
  launch_template_id = module.launch_template.launch_template_id
  target_group_arn   = module.alb.target_group_arn

  min_size         = var.min_size
  desired_capacity = var.desired_capacity
  max_size         = var.max_size

  scale_out_threshold    = var.scale_out_cpu
  scale_in_threshold     = var.scale_in_cpu
  critical_cpu_threshold = var.critical_cpu

  metrics_namespace       = var.metrics_namespace
  alb_arn_suffix          = module.alb.alb_arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix

  alarm_notification_arns = var.alarm_email == null ? [] : [aws_sns_topic.alarms[0].arn]
}

# ---------------------------------------------------------------------------
# Operational dashboard
# ---------------------------------------------------------------------------
# One CloudWatch dashboard gathering the metrics the assignment asks to watch:
# CPU, memory, network, and load balancer health, all in a single view.

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dev"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "CPU Utilization (%)"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", module.autoscaling.autoscaling_group_name]
          ]
          annotations = {
            horizontal = [
              { label = "scale out", value = var.scale_out_cpu },
              { label = "scale in", value = var.scale_in_cpu },
              { label = "critical", value = var.critical_cpu },
            ]
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Memory Utilization (%)"
          region = var.aws_region
          view   = "timeSeries"
          metrics = [
            [var.metrics_namespace, "MemoryUtilization", "AutoScalingGroupName", module.autoscaling.autoscaling_group_name]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Network (bytes)"
          region = var.aws_region
          view   = "timeSeries"
          metrics = [
            ["AWS/EC2", "NetworkIn", "AutoScalingGroupName", module.autoscaling.autoscaling_group_name],
            ["AWS/EC2", "NetworkOut", "AutoScalingGroupName", module.autoscaling.autoscaling_group_name],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ALB requests and healthy hosts"
          region = var.aws_region
          view   = "timeSeries"
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", module.alb.alb_arn_suffix, { stat = "Sum" }],
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", module.alb.target_group_arn_suffix, "LoadBalancer", module.alb.alb_arn_suffix],
          ]
        }
      },
    ]
  })
}
