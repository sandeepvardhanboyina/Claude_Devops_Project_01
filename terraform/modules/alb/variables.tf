variable "name" {
  description = "Name prefix applied to all resources in this module."
  type        = string

  validation {
    # ALB and target group names are capped at 32 characters, and the module
    # appends "-alb"/"-tg". Failing here beats a confusing AWS API error.
    condition     = length(var.name) <= 28
    error_message = "The name must be 28 characters or fewer: AWS caps load balancer and target group names at 32 and this module appends a suffix."
  }
}

variable "vpc_id" {
  description = "ID of the VPC the target group belongs to."
  type        = string
}

variable "subnet_ids" {
  description = "Subnets to place the load balancer in. Must span at least two Availability Zones."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "An Application Load Balancer requires subnets in at least two Availability Zones."
  }
}

variable "security_group_id" {
  description = "ID of the ALB security group, from the security-group module."
  type        = string
}

variable "app_port" {
  description = "Port on the instances that the load balancer forwards to."
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "Path the load balancer polls to judge target health. Served by nginx directly, so it fails if nginx is broken."
  type        = string
  default     = "/health"
}

variable "deregistration_delay" {
  description = "Seconds to wait for in-flight requests before removing a target. Static responses complete quickly, so this is short."
  type        = number
  default     = 30

  validation {
    condition     = var.deregistration_delay >= 0 && var.deregistration_delay <= 3600
    error_message = "The deregistration_delay must be between 0 and 3600 seconds."
  }
}

variable "idle_timeout" {
  description = "Seconds an idle connection is held open."
  type        = number
  default     = 60
}

variable "enable_deletion_protection" {
  description = "Block accidental deletion of the load balancer. Set false to allow terraform destroy to remove it."
  type        = bool
  default     = false
}

variable "access_logs_bucket" {
  description = "S3 bucket for ALB access logs. Leave null to disable; the bucket needs its own ALB-writable policy."
  type        = string
  default     = null
}
