output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.this.dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.this.arn
}

output "target_group_arn" {
  description = "ARN of the ALB target group"
  value       = aws_lb_target_group.this.arn
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.app.name
}

output "launch_template_id" {
  description = "ID of the EC2 Launch Template"
  value       = aws_launch_template.app.id
}

output "launch_template_latest_version" {
  description = "Latest version number of the Launch Template"
  value       = aws_launch_template.app.latest_version
}

output "app_security_group_id" {
  description = "ID of the application EC2 security group"
  value       = aws_security_group.app.id
}

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "app_url" {
  description = "HTTP URL of the application via the load balancer"
  value       = "http://${aws_lb.this.dns_name}"
}
