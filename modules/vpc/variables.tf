variable "name" {
  description = "Base name prefix for all resources in this VPC"
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.cidr_block))
    error_message = "cidr_block must be a valid CIDR notation."
  }
}

variable "subnets" {
  description = "Map of subnets to create. Each entry must have cidr, az, and type (public|private)."
  type = map(object({
    cidr = string
    az   = string
    type = string
  }))

  validation {
    condition = alltrue([
      for k, v in var.subnets : contains(["public", "private"], v.type)
    ])
    error_message = "Each subnet type must be either 'public' or 'private'."
  }
}

variable "enable_nat_gateway" {
  description = "Whether to create a NAT Gateway for private subnet outbound access"
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Whether to enable VPC Flow Logs to S3"
  type        = bool
  default     = false
}

variable "flow_log_role_arn" {
  description = "IAM role ARN for VPC Flow Log delivery (required when enable_flow_logs = true)"
  type        = string
  default     = ""
}

variable "flow_log_bucket_arn" {
  description = "S3 bucket ARN for flow log delivery (required when enable_flow_logs = true)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
