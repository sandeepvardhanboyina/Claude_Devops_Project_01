# Remote state in S3 with DynamoDB locking.
#
# This block is deliberately empty — "partial configuration". The bucket name,
# key, region and lock table are supplied at init time, not committed here:
#
#   terraform init -backend-config=backend.hcl
#
# Keeping the bucket name out of version control is what the assignment means by
# "the backend must not hardcode bucket names": the same code can point at a
# different state store per account or environment without an edit.
terraform {
  backend "s3" {}
}
