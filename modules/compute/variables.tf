variable "name" {
  description = "Base name prefix for compute resources"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC to deploy compute resources into"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EC2 instances"
  type        = list(string)
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
  default     = "ami-0c55b159cbfafe1f0" # Amazon Linux 2 us-east-1 placeholder
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^[a-z][0-9][a-z]?\\.[a-z0-9]+$", var.instance_type))
    error_message = "instance_type must be a valid EC2 instance type (e.g. t3.micro)."
  }
}

variable "min_size" {
  description = "Minimum number of instances in the ASG"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances in the ASG"
  type        = number
  default     = 4
}

variable "desired_capacity" {
  description = "Desired number of instances in the ASG"
  type        = number
  default     = 2
}

variable "cpu_target_utilization" {
  description = "Target CPU utilization percentage for auto-scaling"
  type        = number
  default     = 70
}

variable "app_port" {
  description = "Port the application listens on"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "HTTP path for ALB health checks"
  type        = string
  default     = "/health/ready"
}

variable "root_volume_size_gb" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 20
}

variable "instance_role_name" {
  description = "IAM role name to attach to EC2 instances (via instance profile)"
  type        = string
}

variable "config_s3_bucket" {
  description = "S3 bucket name for application configuration files"
  type        = string
  default     = ""
}

variable "access_log_bucket" {
  description = "S3 bucket name for ALB access logs"
  type        = string
  default     = ""
}

variable "enable_access_logs" {
  description = "Whether to enable ALB access logs"
  type        = bool
  default     = false
}

variable "app_version" {
  description = "Application version to pass to user data"
  type        = string
  default     = "latest"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "alarm_sns_arns" {
  description = "List of SNS topic ARNs to notify on CloudWatch alarms"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
