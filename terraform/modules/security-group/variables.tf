variable "name" {
  description = "Name prefix applied to all resources in this module."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC the security groups belong to."
  type        = string
}

variable "app_port" {
  description = "Port the web server listens on and the ALB forwards to."
  type        = number
  default     = 80

  validation {
    condition     = var.app_port > 0 && var.app_port <= 65535
    error_message = "The app_port must be between 1 and 65535."
  }
}

variable "allowed_ssh_cidr" {
  description = <<-EOT
    Single address permitted to open an SSH session, in CIDR form, for example
    "203.0.113.42/32". Set to null to create no SSH rule at all, which is the
    right choice when management happens through SSM Session Manager.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.allowed_ssh_cidr == null || can(cidrhost(try(var.allowed_ssh_cidr, "10.0.0.0/32"), 0))
    error_message = "The allowed_ssh_cidr must be a valid IPv4 CIDR block, for example 203.0.113.42/32."
  }

  validation {
    condition     = var.allowed_ssh_cidr != "0.0.0.0/0"
    error_message = "Refusing to open SSH to the whole internet. Supply your own address as a /32, or use null to disable SSH entirely."
  }
}
