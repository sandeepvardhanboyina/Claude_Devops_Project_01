variable "name" {
  description = "Name prefix applied to all resources in this module."
  type        = string
}

variable "enable_ssm" {
  description = "Attach AmazonSSMManagedInstanceCore, allowing shell access through Session Manager without SSH."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# GitHub Actions OIDC
# ---------------------------------------------------------------------------

variable "enable_github_oidc" {
  description = "Create a role GitHub Actions can assume via OIDC, removing the need for a long-lived AWS access key."
  type        = bool
  default     = false
}

variable "github_oidc_provider_arn" {
  description = "ARN of the existing GitHub OIDC provider in this account. Required when enable_github_oidc is true."
  type        = string
  default     = ""
}

variable "github_repository" {
  description = "Repository allowed to assume the role, as \"owner/repo\"."
  type        = string
  default     = ""

  validation {
    condition     = var.github_repository == "" || can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "The github_repository must be in \"owner/repo\" form, for example akshansh/claude-first-project."
  }
}

variable "github_allowed_refs" {
  description = <<-EOT
    Git refs permitted to assume the role, as OIDC subject suffixes. Defaults to
    the main branch and pull requests: main can deploy, PRs can only plan.
    Widening this to "*" would let any branch in the repo assume the role.
  EOT
  type        = list(string)
  default     = ["ref:refs/heads/main", "pull_request"]
}

variable "state_bucket_arn" {
  description = "ARN of the S3 bucket holding Terraform state, granted read access for plan runs."
  type        = string
  default     = ""
}

variable "state_lock_table_arn" {
  description = "ARN of the DynamoDB table used for state locking."
  type        = string
  default     = ""
}
