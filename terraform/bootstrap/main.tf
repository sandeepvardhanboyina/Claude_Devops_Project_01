# Bootstrap: creates the S3 bucket and DynamoDB table that hold Terraform's
# remote state for every other configuration.
#
# The chicken-and-egg problem: remote state needs a bucket, but a bucket is
# itself state. So this configuration keeps its OWN state local (there is no
# backend block here) and is applied once, by hand, before anything else.
#
#   cd terraform/bootstrap
#   terraform init && terraform apply
#   terraform output backend_config   # copy these into the dev init

data "aws_caller_identity" "current" {}

locals {
  # The account ID makes the bucket name globally unique without anyone having
  # to invent one, and without a name being hardcoded anywhere. S3 bucket names
  # share one global namespace, so "project-tfstate" alone would collide.
  bucket_name = coalesce(
    var.state_bucket_name,
    "${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}",
  )
}

resource "aws_s3_bucket" "state" {
  bucket = local.bucket_name

  # A state bucket should outlive a careless `terraform destroy`. Removing it
  # means deliberately setting this to false first.
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name    = local.bucket_name
    Purpose = "terraform-remote-state"
  }
}

# Versioning turns a corrupted or truncated state push into an inconvenience
# rather than a disaster: any earlier version can be restored.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# State is plaintext and contains secrets — resource attributes, generated
# passwords, private keys. Encrypt it at rest.
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Nothing about state should ever be public. This blocks it at the bucket level
# regardless of any object ACL.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Expire old non-current versions so the bucket does not grow without bound,
# while keeping enough history to recover from a bad apply.
resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.state]
}

# The lock table stops two people (or a person and a CI job) from applying at
# the same time and racing each other's writes into a corrupt state.
resource "aws_dynamodb_table" "lock" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST" # no idle cost; a lock table sees tiny traffic
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name    = var.lock_table_name
    Purpose = "terraform-state-locking"
  }
}
