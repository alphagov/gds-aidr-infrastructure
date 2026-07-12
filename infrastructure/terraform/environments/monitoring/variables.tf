# environments/monitoring/variables.tf

variable "development_account_id" {
  description = "AWS account ID for the Development account."
  type        = string
}

variable "staging_account_id" {
  description = "AWS account ID for the Staging account."
  type        = string
}

variable "production_account_id" {
  description = "AWS account ID for the Production account."
  type        = string
}

variable "role_prefix" {
  description = "Prefix for all resource names."
  type        = string
  default     = "gds-aidr"
}

variable "digest_email" {
  description = "Email address to receive the weekly CloudTrail digest."
  type        = string
}
