output "instance_role_arn" {
  description = "ARN of the EC2 instance role."
  value       = aws_iam_role.instance.arn
}

output "instance_role_name" {
  description = "Name of the EC2 instance role."
  value       = aws_iam_role.instance.name
}

output "instance_profile_name" {
  description = "Name of the instance profile, for use in the launch template."
  value       = aws_iam_instance_profile.instance.name
}

output "instance_profile_arn" {
  description = "ARN of the instance profile."
  value       = aws_iam_instance_profile.instance.arn
}

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions OIDC role. Empty when enable_github_oidc is false. Set this as the AWS_ROLE_ARN repository secret."
  value       = try(aws_iam_role.github_actions[0].arn, "")
}
