output "ec2_instance_role_name" {
  description = "Name of the EC2 instance IAM role"
  value       = aws_iam_role.ec2_instance.name
}

output "ec2_instance_role_arn" {
  description = "ARN of the EC2 instance IAM role"
  value       = aws_iam_role.ec2_instance.arn
}

output "cicd_deploy_role_arn" {
  description = "ARN of the CI/CD deployment role (empty if not enabled)"
  value       = var.enable_cicd_role ? aws_iam_role.cicd_deploy[0].arn : ""
}

output "s3_config_read_policy_arn" {
  description = "ARN of the S3 config read policy"
  value       = aws_iam_policy.s3_config_read.arn
}

output "cloudwatch_policy_arn" {
  description = "ARN of the CloudWatch policy"
  value       = aws_iam_policy.cloudwatch.arn
}
