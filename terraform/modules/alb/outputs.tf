output "alb_arn" {
  description = "ARN of the load balancer."
  value       = aws_lb.this.arn
}

output "alb_arn_suffix" {
  description = "ARN suffix of the load balancer, the form CloudWatch metric dimensions require."
  value       = aws_lb.this.arn_suffix
}

output "alb_dns_name" {
  description = "Public DNS name of the load balancer. This is the site's address."
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Hosted zone ID of the load balancer, for a Route 53 alias record."
  value       = aws_lb.this.zone_id
}

output "target_group_arn" {
  description = "ARN of the target group. The Auto Scaling Group attaches to this."
  value       = aws_lb_target_group.this.arn
}

output "target_group_arn_suffix" {
  description = "ARN suffix of the target group, for CloudWatch metric dimensions."
  value       = aws_lb_target_group.this.arn_suffix
}

output "website_url" {
  description = "Fully qualified URL of the deployed site."
  value       = "http://${aws_lb.this.dns_name}"
}
