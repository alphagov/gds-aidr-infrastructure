# environments/compute/variables.tf

variable "development_account_id" {
  description = "AWS account ID for the development account."
  type        = string
}

variable "development_api_image_tag" {
  description = "Image tag for the synthetic-email-generation"
  type        = string
}

variable "development_ui_image_tag" {
  description = "Image tag for the synthetic-email-generation-ui service, prefixed ui- to distinguish it in the shared repo. No default — must always be supplied explicitly."
  type        = string
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

variable "bedrock_model_id" {
  description = "Bedrock model ID or EU cross-region inference profile ID for Claude. Must be confirmed via the Bedrock console or CLI, not guessed."
  type        = string
}
