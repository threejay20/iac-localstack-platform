# ============================================================
# Storage Module — S3 buckets with versioning, encryption,
# lifecycle policies, replication config, and access logging.
# ============================================================

# ---------- Primary application data bucket ----------
resource "aws_s3_bucket" "app" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy

  tags = merge(var.tags, { Name = var.bucket_name })
}

# Block ALL public access — explicit security posture
resource "aws_s3_bucket_public_access_block" "app" {
  bucket = aws_s3_bucket.app.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning — enables point-in-time recovery
resource "aws_s3_bucket_versioning" "app" {
  bucket = aws_s3_bucket.app.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# Server-side encryption with AES256 (or KMS if key provided)
resource "aws_s3_bucket_server_side_encryption_configuration" "app" {
  bucket = aws_s3_bucket.app.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != "" ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn != "" ? var.kms_key_arn : null
    }
    bucket_key_enabled = var.kms_key_arn != "" ? true : false
  }
}

# Lifecycle policy — transition and expiration rules
resource "aws_s3_bucket_lifecycle_configuration" "app" {
  bucket = aws_s3_bucket.app.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    filter {
      prefix = ""
    }

    # Move infrequently accessed objects after 30 days
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # Archive after 90 days
    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # Delete non-current versions after 30 days
    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    # Remove incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  dynamic "rule" {
    for_each = var.expiration_days > 0 ? [1] : []
    content {
      id     = "expire-objects"
      status = "Enabled"
      filter { prefix = "" }
      expiration {
        days = var.expiration_days
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.app]
}

# Bucket policy — enforce HTTPS only (deny HTTP)
resource "aws_s3_bucket_policy" "enforce_https" {
  count  = var.enforce_https ? 1 : 0
  bucket = aws_s3_bucket.app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureConnections"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.app.arn,
          "${aws_s3_bucket.app.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.app]
}

# CORS configuration (optional — only for web-accessible buckets)
resource "aws_s3_bucket_cors_configuration" "app" {
  count  = length(var.cors_allowed_origins) > 0 ? 1 : 0
  bucket = aws_s3_bucket.app.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = var.cors_allowed_origins
    expose_headers  = ["ETag"]
    max_age_seconds = 3600
  }
}

# ---------- Access log bucket (separate, private) ----------
resource "aws_s3_bucket" "access_logs" {
  count  = var.enable_access_logging ? 1 : 0
  bucket = "${var.bucket_name}-access-logs"

  tags = merge(var.tags, { Name = "${var.bucket_name}-access-logs" })
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  count  = var.enable_access_logging ? 1 : 0
  bucket = aws_s3_bucket.access_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "app" {
  count  = var.enable_access_logging ? 1 : 0
  bucket = aws_s3_bucket.app.id

  target_bucket = aws_s3_bucket.access_logs[0].id
  target_prefix = "access-logs/"
}
