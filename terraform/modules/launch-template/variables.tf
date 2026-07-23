variable "name" {
  description = "Name prefix applied to all resources in this module."
  type        = string
}

variable "ami_id" {
  description = "AMI to launch. Leave null to resolve the latest Ubuntu 22.04 LTS image published by Canonical."
  type        = string
  default     = null
}

variable "instance_type" {
  description = "EC2 instance type. t3.micro is free-tier eligible and ample for serving static files."
  type        = string
  default     = "t3.micro"
}

variable "security_group_id" {
  description = "ID of the instance security group, from the security-group module."
  type        = string
}

variable "instance_profile_name" {
  description = "Name of the IAM instance profile, from the iam module."
  type        = string
}

variable "key_name" {
  description = <<-EOT
    EC2 key pair name for SSH access, required by the pipeline's rsync deploy.
    Leave null when managing instances solely through SSM Session Manager.
  EOT
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Size of the encrypted gp3 root volume, in GiB."
  type        = number
  default     = 20

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 100
    error_message = "The root_volume_size must be between 8 and 100 GiB."
  }
}

variable "enable_detailed_monitoring" {
  description = "Report EC2 metrics every minute instead of every five. Improves scaling responsiveness; costs extra beyond the free tier."
  type        = bool
  default     = true
}

variable "enable_cloudwatch_agent" {
  description = "Install and configure the CloudWatch agent, which is the only way to collect memory and disk metrics."
  type        = bool
  default     = true
}

variable "metrics_namespace" {
  description = "CloudWatch namespace the agent publishes custom metrics under."
  type        = string
  default     = "ClaudeFirstProject"
}
