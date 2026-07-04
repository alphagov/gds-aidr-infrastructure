# environments/containers/variables.tf

variable "development_account_id" {
  description = "AWS account ID for the development account."
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
  description = "Prefix for IAM role names, used to reference the existing terraform role created by production-iam."
  type        = string
  default     = "gds-aidr"
}

variable "repository_names" {
  description = "List of ECR repository names to create in each account."
  type        = list(string)
  default     = ["synthetic-email-generation"]
}
