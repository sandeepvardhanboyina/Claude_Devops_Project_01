variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix and tag applied across the environment. Kept short so it fits AWS name limits for the ALB and target group."
  type        = string
  default     = "claude-first-project"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,26}$", var.project_name))
    error_message = "The project_name must be lowercase letters, numbers and hyphens, start with a letter, and be 27 characters or fewer."
  }
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets, one per Availability Zone."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "az_count" {
  description = "Number of Availability Zones to spread across. Two is the minimum for a load-balanced deployment."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 4
    error_message = "The az_count must be between 2 and 4."
  }
}

# ---------------------------------------------------------------------------
# Instances
# ---------------------------------------------------------------------------

variable "instance_type" {
  description = "EC2 instance type. t3.micro is free-tier eligible."
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = <<-EOT
    Name of an existing EC2 key pair for SSH, used by the deploy pipeline's
    rsync. Leave null to manage instances only through SSM Session Manager.
  EOT
  type        = string
  default     = null
}

variable "allowed_ssh_cidr" {
  description = <<-EOT
    Single address allowed to SSH to instances, as a /32, for example
    "203.0.113.42/32". Leave null to open no SSH port at all. The module
    refuses 0.0.0.0/0 outright.
  EOT
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Size of each instance's encrypted root volume, in GiB."
  type        = number
  default     = 20
}

# ---------------------------------------------------------------------------
# Auto Scaling
# ---------------------------------------------------------------------------

variable "min_size" {
  description = "Minimum number of instances."
  type        = number
  default     = 1
}

variable "desired_capacity" {
  description = "Steady-state instance count."
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of instances."
  type        = number
  default     = 4
}

variable "scale_out_cpu" {
  description = "CPU percentage above which to add an instance."
  type        = number
  default     = 70
}

variable "scale_in_cpu" {
  description = "CPU percentage below which to remove an instance."
  type        = number
  default     = 30
}

variable "critical_cpu" {
  description = "CPU percentage that raises an alert without scaling."
  type        = number
  default     = 80
}

# ---------------------------------------------------------------------------
# Monitoring
# ---------------------------------------------------------------------------

variable "metrics_namespace" {
  description = "CloudWatch namespace for custom (memory, disk) metrics. Shared by the launch template and the alarms."
  type        = string
  default     = "ClaudeFirstProject"
}

variable "alarm_email" {
  description = "Email address subscribed to alarm notifications. Leave null to create alarms with no notification target."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# CI/CD
# ---------------------------------------------------------------------------

variable "enable_github_oidc" {
  description = "Create the GitHub Actions OIDC role. Requires the GitHub OIDC provider to already exist in the account."
  type        = bool
  default     = false
}

variable "github_oidc_provider_arn" {
  description = "ARN of the existing GitHub OIDC provider. Required when enable_github_oidc is true."
  type        = string
  default     = ""
}

variable "github_repository" {
  description = "Repository allowed to assume the OIDC role, as \"owner/repo\"."
  type        = string
  default     = ""
}

variable "state_bucket_arn" {
  description = "ARN of the state bucket, granted to the OIDC role for plan runs. From the bootstrap output."
  type        = string
  default     = ""
}

variable "state_lock_table_arn" {
  description = "ARN of the lock table, granted to the OIDC role. From the bootstrap output."
  type        = string
  default     = ""
}
