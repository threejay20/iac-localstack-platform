# ============================================================
# Dev environment — wires up all modules with dev-appropriate
# sizing and settings. Runs against LocalStack locally.
# ============================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # S3 backend simulated by LocalStack
  backend "s3" {
    bucket                      = "terraform-state-dev"
    key                         = "dev/terraform.tfstate"
    region                      = "us-east-1"
    endpoint                    = "http://localhost:4566"
    access_key                  = "test"
    secret_key                  = "test"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
  }
}

provider "aws" {
  region                      = var.aws_region
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    ec2            = "http://localhost:4566"
    s3             = "http://localhost:4566"
    iam            = "http://localhost:4566"
    sts            = "http://localhost:4566"
    autoscaling    = "http://localhost:4566"
    elasticloadbalancingv2 = "http://localhost:4566"
    cloudwatch     = "http://localhost:4566"
    logs           = "http://localhost:4566"
    sns            = "http://localhost:4566"
  }
}

locals {
  environment = "dev"
  name_prefix = "${var.project_name}-${local.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = local.environment
    ManagedBy   = "terraform"
    Owner       = "platform-team"
    CostCenter  = "engineering"
  }
}

# ---------- IAM first (compute needs role name) ----------
module "iam" {
  source = "../../modules/iam"

  name                 = local.name_prefix
  aws_region           = var.aws_region
  aws_account_id       = var.aws_account_id
  config_bucket_name   = "${local.name_prefix}-config"
  app_data_bucket_name = "${local.name_prefix}-app-data"
  enable_ssm           = true
  enable_cicd_role     = false

  tags = local.common_tags
}

# ---------- VPC ----------
module "vpc" {
  source = "../../modules/vpc"

  name       = local.name_prefix
  cidr_block = var.vpc_cidr

  subnets = {
    public-a = { cidr = "10.10.0.0/24", az = "${var.aws_region}a", type = "public" }
    public-b = { cidr = "10.10.1.0/24", az = "${var.aws_region}b", type = "public" }
    private-a = { cidr = "10.10.10.0/24", az = "${var.aws_region}a", type = "private" }
    private-b = { cidr = "10.10.11.0/24", az = "${var.aws_region}b", type = "private" }
  }

  # Dev: no NAT gateway to save simulated cost
  enable_nat_gateway = false
  enable_flow_logs   = false

  tags = local.common_tags
}

# ---------- Storage: config bucket ----------
module "config_bucket" {
  source = "../../modules/storage"

  bucket_name       = "${local.name_prefix}-config"
  enable_versioning = true
  force_destroy     = true  # OK for dev
  enforce_https     = false # LocalStack does not enforce HTTPS
  expiration_days   = 90

  tags = merge(local.common_tags, { Purpose = "app-config" })
}

# ---------- Storage: app data bucket ----------
module "app_data_bucket" {
  source = "../../modules/storage"

  bucket_name       = "${local.name_prefix}-app-data"
  enable_versioning = false
  force_destroy     = true
  enforce_https     = false
  expiration_days   = 30

  tags = merge(local.common_tags, { Purpose = "app-data" })
}

# ---------- Compute ----------
module "compute" {
  source = "../../modules/compute"

  name               = local.name_prefix
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids

  ami_id             = var.ami_id
  instance_type      = "t3.micro"
  min_size           = 1
  max_size           = 2
  desired_capacity   = 1

  instance_role_name    = module.iam.ec2_instance_role_name
  config_s3_bucket      = module.config_bucket.bucket_id
  app_version           = var.app_version
  environment           = local.environment
  health_check_path     = "/health/ready"
  enable_access_logs    = false
  access_log_bucket     = ""
  alarm_sns_arns        = []

  tags = local.common_tags

  depends_on = [module.iam, module.vpc]
}
