variable "project_name" {
  type    = string
  default = "iac-demo"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_account_id" {
  type    = string
  default = "000000000000"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "ami_id" {
  type    = string
  default = "ami-0c55b159cbfafe1f0"
}

variable "app_version" {
  type    = string
  default = "latest"
}

variable "github_repo" {
  description = "GitHub repo in owner/repo format for the CI/CD OIDC trust policy"
  type        = string
  default     = "OWNER/REPO"
}
