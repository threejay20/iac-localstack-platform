variable "name" {
  description = "Base name prefix for IAM resources"
  type        = string
}

variable "aws_region" {
  description = "AWS region where resources are deployed (used in IAM condition keys)"
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "AWS account ID (required when enable_cicd_role = true)"
  type        = string
  default     = "000000000000"
}

variable "config_bucket_name" {
  description = "Name of the S3 bucket containing application configuration"
  type        = string
}

variable "app_data_bucket_name" {
  description = "Name of the S3 bucket for application data"
  type        = string
}

variable "enable_ssm" {
  description = "Whether to create and attach the SSM managed instance policy"
  type        = bool
  default     = true
}

variable "enable_cicd_role" {
  description = "Whether to create the GitHub Actions OIDC CI/CD deployment role"
  type        = bool
  default     = false
}

variable "github_repo" {
  description = "GitHub repository in owner/repo format for OIDC trust (e.g. myorg/myapp)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all IAM resources"
  type        = map(string)
  default     = {}
}
