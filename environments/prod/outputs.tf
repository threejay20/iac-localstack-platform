output "vpc_id" {
  value = module.vpc.vpc_id
}

output "alb_dns_name" {
  value = module.compute.alb_dns_name
}

output "app_url" {
  value = module.compute.app_url
}

output "config_bucket" {
  value = module.config_bucket.bucket_id
}

output "app_data_bucket" {
  value = module.app_data_bucket.bucket_id
}

output "ec2_instance_role_arn" {
  value = module.iam.ec2_instance_role_arn
}

output "cicd_deploy_role_arn" {
  description = "Role ARN for GitHub Actions OIDC deployment"
  value       = module.iam.cicd_deploy_role_arn
}
