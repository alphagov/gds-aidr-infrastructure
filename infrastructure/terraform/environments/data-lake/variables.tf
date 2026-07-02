# environments/data-lake/variables.tf

variable "production_account_id" {
  description = "AWS account ID for the Production account, where the lake lives."
  type        = string
}

variable "bucket_name" {
  description = "Name of the data lake bucket."
  type        = string
  default     = "gds-aidr-synthetic-data-library"
}

variable "dataset_prefix" {
  description = "Prefix for dataset files."
  type        = string
  default     = "datasets/email/v1/"
}

variable "metadata_prefix" {
  description = "Prefix for metadata files."
  type        = string
  default     = "metadata/email/v1/"
}

variable "reader_account_arns" {
  description = "Account root ARNs permitted to read the lake cross-account. Development and Staging roots for internal use; cross-government roots added."
  type        = list(string)
  default     = []
}

variable "lakeformation_register_role_arn" {
  description = "ARN of the role Lake Formation uses to access the registered metadata location."
  type        = string
}

variable "audit_log_retention_days" {
  description = "How long object-level audit logs are retained."
  type        = number
  default     = 365
}
