output "launch_template_id" {
  description = "ID of the launch template."
  value       = aws_launch_template.this.id
}

output "launch_template_arn" {
  description = "ARN of the launch template."
  value       = aws_launch_template.this.arn
}

output "latest_version" {
  description = "Latest version number of the launch template. The ASG tracks this so a template change triggers an instance refresh."
  value       = aws_launch_template.this.latest_version
}

output "ami_id" {
  description = "AMI the template launches."
  value       = local.ami_id
}

output "metrics_namespace" {
  description = "CloudWatch namespace the agent publishes to, needed by the autoscaling module's memory alarm."
  value       = var.metrics_namespace
}
