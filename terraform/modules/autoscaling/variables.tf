variable "name" {
  description = "Name prefix applied to all resources in this module."
  type        = string
}

variable "subnet_ids" {
  description = "Subnets the group launches instances into. Should span two Availability Zones."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least two subnets are required so instances are spread across Availability Zones."
  }
}

variable "launch_template_id" {
  description = "ID of the launch template, from the launch-template module."
  type        = string
}

variable "launch_template_version" {
  description = "Launch template version to launch from. \"$Latest\" picks up template changes and, with instance refresh enabled, rolls the fleet automatically."
  type        = string
  default     = "$Latest"
}

variable "target_group_arn" {
  description = "ARN of the ALB target group to register instances with."
  type        = string
}

# ---------------------------------------------------------------------------
# Capacity
# ---------------------------------------------------------------------------

variable "min_size" {
  description = "Minimum number of instances."
  type        = number
  default     = 1
}

variable "desired_capacity" {
  description = "Instance count at steady state. Two means one can fail without an outage."
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of instances."
  type        = number
  default     = 4
}

variable "health_check_grace_period" {
  description = "Seconds before health checks count against a new instance. Must exceed bootstrap time or instances are killed mid-install."
  type        = number
  default     = 300
}

variable "cooldown" {
  description = "Seconds after a scaling action before another may start."
  type        = number
  default     = 300
}

variable "enable_instance_refresh" {
  description = "Roll instances automatically when the launch template changes."
  type        = bool
  default     = true
}

variable "additional_tags" {
  description = "Extra tags propagated to launched instances."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Scaling thresholds
# ---------------------------------------------------------------------------

variable "scale_out_threshold" {
  description = "CPU percentage above which capacity is added."
  type        = number
  default     = 70

  validation {
    condition     = var.scale_out_threshold > 0 && var.scale_out_threshold <= 100
    error_message = "The scale_out_threshold must be between 1 and 100."
  }
}

variable "scale_in_threshold" {
  description = "CPU percentage below which capacity is removed."
  type        = number
  default     = 30

  validation {
    condition     = var.scale_in_threshold > 0 && var.scale_in_threshold <= 100
    error_message = "The scale_in_threshold must be between 1 and 100."
  }
}

variable "critical_cpu_threshold" {
  description = "CPU percentage that raises an alert without triggering a scaling action."
  type        = number
  default     = 80
}

variable "scale_out_adjustment" {
  description = "Instances added when the scale-out alarm fires."
  type        = number
  default     = 1
}

variable "scale_in_adjustment" {
  description = "Instances removed when the scale-in alarm fires. Must be negative."
  type        = number
  default     = -1

  validation {
    condition     = var.scale_in_adjustment < 0
    error_message = "The scale_in_adjustment must be negative: a positive value would add capacity when CPU is low."
  }
}

variable "alarm_period" {
  description = "Seconds in each alarm evaluation period. 60 requires detailed monitoring on the instances."
  type        = number
  default     = 60
}

variable "scale_out_evaluation_periods" {
  description = "Consecutive breaching periods before scaling out. Kept low so the fleet reacts quickly to load."
  type        = number
  default     = 2
}

variable "scale_in_evaluation_periods" {
  description = "Consecutive periods below threshold before scaling in. Higher than scale-out to avoid thrashing."
  type        = number
  default     = 5
}

# ---------------------------------------------------------------------------
# Additional alarms
# ---------------------------------------------------------------------------

variable "enable_memory_alarm" {
  description = "Create the memory alarm. Requires the CloudWatch agent, installed by the launch template."
  type        = bool
  default     = true
}

variable "memory_threshold" {
  description = "Memory percentage that raises an alert."
  type        = number
  default     = 80
}

variable "metrics_namespace" {
  description = "CloudWatch namespace the agent publishes memory metrics under. Must match the launch-template module."
  type        = string
  default     = "ClaudeFirstProject"
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the load balancer, for the unhealthy-host alarm dimensions."
  type        = string
  default     = null
}

variable "target_group_arn_suffix" {
  description = "ARN suffix of the target group. Leave null to skip the unhealthy-host alarm."
  type        = string
  default     = null
}

variable "alarm_notification_arns" {
  description = "SNS topic ARNs notified when alarms change state. Empty means alarms are visible in the console but send nothing."
  type        = list(string)
  default     = []
}
