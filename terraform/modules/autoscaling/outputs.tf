output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group."
  value       = aws_autoscaling_group.this.name
}

output "autoscaling_group_arn" {
  description = "ARN of the Auto Scaling Group."
  value       = aws_autoscaling_group.this.arn
}

output "min_size" {
  description = "Configured minimum capacity."
  value       = aws_autoscaling_group.this.min_size
}

output "desired_capacity" {
  description = "Configured desired capacity at creation time. Live capacity drifts as scaling policies act."
  value       = aws_autoscaling_group.this.desired_capacity
}

output "max_size" {
  description = "Configured maximum capacity."
  value       = aws_autoscaling_group.this.max_size
}

output "scale_out_policy_arn" {
  description = "ARN of the scale-out policy."
  value       = aws_autoscaling_policy.scale_out.arn
}

output "scale_in_policy_arn" {
  description = "ARN of the scale-in policy."
  value       = aws_autoscaling_policy.scale_in.arn
}

output "alarm_names" {
  description = "Names of every CloudWatch alarm created by this module."
  value = compact([
    aws_cloudwatch_metric_alarm.cpu_high.alarm_name,
    aws_cloudwatch_metric_alarm.cpu_low.alarm_name,
    aws_cloudwatch_metric_alarm.cpu_critical.alarm_name,
    try(aws_cloudwatch_metric_alarm.memory_high[0].alarm_name, ""),
    try(aws_cloudwatch_metric_alarm.unhealthy_hosts[0].alarm_name, ""),
  ])
}
