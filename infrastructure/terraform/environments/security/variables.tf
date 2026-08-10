# ============================================================
# Security Environment - Variables
# ============================================================
# Cross-cutting security concerns for the AIDR platform: DNS,
# wildcard certificate, and application subdomain routing.
# Applies across all workload environments (Development,
# Staging, Production).
# ============================================================

# --- SCAFFOLDING (deferred) ---
# Not yet used. Uncomment when security env deploys resources
# to Production via provider assume_role (currently the default
# provider uses the caller's session directly, matching compute
# env pattern).
#
# variable "production_account_id" {
#   description = "AWS account ID for the Production account. Security resources deploy here."
#   type        = string
#   sensitive   = true
# }

variable "development_account_id" {
  description = "AWS account ID for the Development account. Referenced for cross-account context."
  type        = string
  sensitive   = true
}

variable "staging_account_id" {
  description = "AWS account ID for the Staging account. Referenced for cross-account context."
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "Root domain for the platform. All application subdomains derive from this."
  type        = string
}

variable "certificate_arn" {
  description = "ARN of the wildcard ACM certificate covering the platform domain. Must be in us-east-1 for CloudFront."
  type        = string
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID for the platform domain."
  type        = string
}

variable "role_prefix" {
  description = "Prefix for cross-account IAM roles (matches compute env pattern)."
  type        = string
  default     = "gds-aidr"
}
