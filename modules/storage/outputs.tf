output "bucket_id" {
  description = "The name (ID) of the S3 bucket"
  value       = aws_s3_bucket.app.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.app.arn
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  value       = aws_s3_bucket.app.bucket_regional_domain_name
}

output "access_log_bucket_id" {
  description = "Name of the access log bucket (empty if logging disabled)"
  value       = var.enable_access_logging ? aws_s3_bucket.access_logs[0].id : ""
}
