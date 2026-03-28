# ============================================================
# IAM Module — roles, policies, and instance profiles following
# least-privilege principles. All policies are explicit allow-lists.
# ============================================================

# ---------- EC2 Instance Role ----------
resource "aws_iam_role" "ec2_instance" {
  name        = "${var.name}-ec2-role"
  description = "IAM role for EC2 application instances — least privilege"
  path        = "/app/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      }
    ]
  })

  tags = merge(var.tags, { Name = "${var.name}-ec2-role" })
}

# ---------- Policy: S3 read for config bucket ----------
resource "aws_iam_policy" "s3_config_read" {
  name        = "${var.name}-s3-config-read"
  description = "Allow EC2 instances to read configuration from the config S3 bucket only"
  path        = "/app/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowConfigBucketRead"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.config_bucket_name}",
          "arn:aws:s3:::${var.config_bucket_name}/config/*"
        ]
      }
    ]
  })

  tags = var.tags
}

# ---------- Policy: S3 write for app data bucket ----------
resource "aws_iam_policy" "s3_app_write" {
  name        = "${var.name}-s3-app-write"
  description = "Allow EC2 instances to write application data to the app data bucket"
  path        = "/app/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAppDataWrite"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.app_data_bucket_name}/data/*"
        ]
      },
      {
        Sid    = "AllowBucketList"
        Effect = "Allow"
        Action = ["s3:ListBucket"]
        Resource = ["arn:aws:s3:::${var.app_data_bucket_name}"]
        Condition = {
          StringLike = {
            "s3:prefix" = ["data/*"]
          }
        }
      }
    ]
  })

  tags = var.tags
}

# ---------- Policy: CloudWatch Logs and metrics ----------
resource "aws_iam_policy" "cloudwatch" {
  name        = "${var.name}-cloudwatch"
  description = "Allow EC2 instances to publish logs and metrics to CloudWatch"
  path        = "/app/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchLogsWrite"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:*:log-group:/ec2/${var.name}/*"
        ]
      },
      {
        Sid    = "AllowCloudWatchMetrics"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowDescribeForCWAgent"
        Effect = "Allow"
        Action = [
          "ec2:DescribeVolumes",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

# ---------- Policy: SSM (Systems Manager) for patch management ----------
resource "aws_iam_policy" "ssm" {
  count       = var.enable_ssm ? 1 : 0
  name        = "${var.name}-ssm"
  description = "Allow SSM agent operations for patch management and session manager"
  path        = "/app/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSSMCore"
        Effect = "Allow"
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssm:ListInstanceAssociations",
          "ssm:DescribeInstanceProperties",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
          "ec2messages:AcknowledgeMessage",
          "ec2messages:DeleteMessage",
          "ec2messages:FailMessage",
          "ec2messages:GetEndpoint",
          "ec2messages:GetMessages",
          "ec2messages:SendReply"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

# ---------- Attach policies to EC2 role ----------
resource "aws_iam_role_policy_attachment" "s3_config_read" {
  role       = aws_iam_role.ec2_instance.name
  policy_arn = aws_iam_policy.s3_config_read.arn
}

resource "aws_iam_role_policy_attachment" "s3_app_write" {
  role       = aws_iam_role.ec2_instance.name
  policy_arn = aws_iam_policy.s3_app_write.arn
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.ec2_instance.name
  policy_arn = aws_iam_policy.cloudwatch.arn
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count      = var.enable_ssm ? 1 : 0
  role       = aws_iam_role.ec2_instance.name
  policy_arn = aws_iam_policy.ssm[0].arn
}

# ---------- CI/CD Deployment Role (assumed by GitHub Actions OIDC) ----------
resource "aws_iam_role" "cicd_deploy" {
  count       = var.enable_cicd_role ? 1 : 0
  name        = "${var.name}-cicd-deploy"
  description = "Role assumed by GitHub Actions via OIDC for deployments — scoped to this application only"
  path        = "/cicd/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${var.aws_account_id}:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
          }
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, { Name = "${var.name}-cicd-deploy" })
}

# ---------- CI/CD Policy: ECR push + ASG refresh ----------
resource "aws_iam_policy" "cicd_deploy" {
  count       = var.enable_cicd_role ? 1 : 0
  name        = "${var.name}-cicd-deploy-policy"
  description = "CI/CD deploy policy — ECR, ASG instance refresh, SSM parameter reads"
  path        = "/cicd/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuthAndPush"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
      {
        Sid    = "ASGInstanceRefresh"
        Effect = "Allow"
        Action = [
          "autoscaling:StartInstanceRefresh",
          "autoscaling:DescribeInstanceRefreshes",
          "autoscaling:CancelInstanceRefresh"
        ]
        Resource = "arn:aws:autoscaling:${var.aws_region}:*:autoScalingGroup:*:autoScalingGroupName/${var.name}-*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cicd_deploy" {
  count      = var.enable_cicd_role ? 1 : 0
  role       = aws_iam_role.cicd_deploy[0].name
  policy_arn = aws_iam_policy.cicd_deploy[0].arn
}
