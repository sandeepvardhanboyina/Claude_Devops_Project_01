terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # No backend block on purpose: this configuration creates the backend, so its
  # own state stays local. Keep the generated terraform.tfstate here safe, or
  # commit nothing and simply re-import if it is ever lost.
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
      Component = "bootstrap"
    }
  }
}
