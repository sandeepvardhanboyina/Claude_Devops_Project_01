variable "name" {
  description = "Name prefix applied to all resources in this module."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name))
    error_message = "The name must contain only lowercase letters, numbers and hyphens."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "The vpc_cidr must be a valid IPv4 CIDR block, for example 10.0.0.0/16."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets. At least two are required so the ALB can span Availability Zones."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "At least two public subnet CIDRs are required: an ALB must have subnets in two Availability Zones."
  }
}

variable "availability_zones" {
  description = "Availability Zones to distribute the public subnets across."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least two Availability Zones are required for a load-balanced, highly available deployment."
  }
}

variable "enable_flow_logs" {
  description = "Whether to capture VPC flow logs to CloudWatch Logs."
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "Retention period for VPC flow logs. Kept short by default to stay inside the free tier."
  type        = number
  default     = 7
}
