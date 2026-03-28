variable "project_name" {
  description = "Project name used as a prefix for all resource names"
  type        = string
  default     = "iac-demo"
}

variable "aws_region" {
  description = "AWS region (simulated by LocalStack)"
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "AWS account ID (LocalStack uses 000000000000)"
  type        = string
  default     = "000000000000"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.10.0.0/16"
}

variable "ami_id" {
  description = "AMI ID for EC2 instances (placeholder for LocalStack)"
  type        = string
  default     = "ami-0c55b159cbfafe1f0"
}

variable "app_version" {
  description = "Application version being deployed"
  type        = string
  default     = "latest"
}
