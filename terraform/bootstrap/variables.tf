variable "aws_region" {
  description = "Region the state bucket and lock table are created in. Should match the region the rest of the project deploys to."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name, used to derive the default state bucket name."
  type        = string
  default     = "claude-first-project"
}

variable "state_bucket_name" {
  description = <<-EOT
    Explicit S3 bucket name for Terraform state. Leave null to derive a
    globally unique name from the project and account ID, which avoids
    hardcoding a name that could collide with another account's bucket.
  EOT
  type        = string
  default     = null
}

variable "lock_table_name" {
  description = "DynamoDB table name for state locking."
  type        = string
  default     = "claude-first-project-tflock"
}

variable "noncurrent_version_retention_days" {
  description = "Days to keep superseded state versions before expiring them."
  type        = number
  default     = 90
}
