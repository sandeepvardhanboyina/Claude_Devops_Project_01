# The one output that matters day to day: where the site lives.
output "website_url" {
  description = "Public URL of the deployed site."
  value       = module.alb.website_url
}

output "alb_dns_name" {
  description = "Load balancer DNS name. Point a CNAME here for a custom domain."
  value       = module.alb.alb_dns_name
}

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = module.vpc.public_subnet_ids
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group, for CLI operations and deploys."
  value       = module.autoscaling.autoscaling_group_name
}

output "instance_security_group_id" {
  description = "Security group attached to the instances."
  value       = module.security_group.instance_security_group_id
}

output "alarm_names" {
  description = "Every CloudWatch alarm created for the environment."
  value       = module.autoscaling.alarm_names
}

output "dashboard_name" {
  description = "CloudWatch dashboard name."
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "github_actions_role_arn" {
  description = "OIDC role ARN for GitHub Actions. Empty unless enable_github_oidc is true. Set as the AWS_ROLE_ARN repo secret."
  value       = module.iam.github_actions_role_arn
}
