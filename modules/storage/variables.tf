variable "bucket_name" {
  description = "Name of the S3 bucket (must be globally unique)"
  type        = string
}

variable "enable_versioning" {
  description = "Enable S3 object versioning"
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "Allow Terraform to destroy non-empty buckets (use only in non-production)"
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "KMS key ARN for SSE-KMS encryption. Leave empty to use SSE-S3 (AES256)."
  type        = string
  default     = ""
}

variable "enforce_https" {
  description = "Attach a bucket policy that denies non-HTTPS requests"
  type        = bool
  default     = true
}

variable "enable_access_logging" {
  description = "Create a separate access log bucket and enable logging"
  type        = bool
  default     = false
}

variable "expiration_days" {
  description = "Number of days after which objects are permanently deleted. 0 disables expiration."
  type        = number
  default     = 0
}

variable "cors_allowed_origins" {
  description = "List of CORS allowed origins. Empty list disables CORS config."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all storage resources"
  type        = map(string)
  default     = {}
}
