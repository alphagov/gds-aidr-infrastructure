# environments/compute/variables.tf

variable "development_account_id" {
  description = "AWS account ID for the development account."
  type        = string
}

variable "development_api_image_tag" {
  description = "Image tag for the synthetic-email-generation API, set automatically by the deploy script — never edited by hand."
  type        = string
  default     = "latest"
}

variable "staging_account_id" {
  description = "AWS account ID for the staging account."
  type        = string
}

variable "production_account_id" {
  description = "AWS account ID for the production account."
  type        = string
}

variable "role_prefix" {
  description = "Prefix for IAM role and resource names, used to reference the existing terraform role created by production-iam."
  type        = string
  default     = "gds-aidr"
}
