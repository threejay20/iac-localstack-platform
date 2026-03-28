output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = module.compute.alb_dns_name
}

output "app_url" {
  description = "Application URL via load balancer"
  value       = module.compute.app_url
}

output "config_bucket" {
  description = "Config S3 bucket name"
  value       = module.config_bucket.bucket_id
}

output "app_data_bucket" {
  description = "App data S3 bucket name"
  value       = module.app_data_bucket.bucket_id
}

output "ec2_instance_role_arn" {
  description = "EC2 instance role ARN"
  value       = module.iam.ec2_instance_role_arn
}
