output "state_bucket_name" {
  description = "Name of the S3 bucket holding Terraform state."
  value       = aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  description = "ARN of the state bucket, for granting the pipeline read access."
  value       = aws_s3_bucket.state.arn
}

output "lock_table_name" {
  description = "Name of the DynamoDB lock table."
  value       = aws_dynamodb_table.lock.name
}

output "lock_table_arn" {
  description = "ARN of the lock table."
  value       = aws_dynamodb_table.lock.arn
}

output "region" {
  description = "Region the backend resources live in."
  value       = var.aws_region
}

# Ready-to-paste -backend-config values for the dev environment's init. This is
# what keeps the bucket name out of any committed file.
output "backend_config" {
  description = "Values to pass to `terraform init -backend-config=...` in environments/dev."
  value = {
    bucket         = aws_s3_bucket.state.id
    key            = "env/dev/terraform.tfstate"
    region         = var.aws_region
    dynamodb_table = aws_dynamodb_table.lock.name
    encrypt        = true
  }
}
