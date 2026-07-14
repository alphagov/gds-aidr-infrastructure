# data-lake/variables.tf

variable "bucket_name" {
  description = "Name of the data lake bucket."
  type        = string
}

variable "production_account_id" {
  description = "AWS account ID of the Production account that owns and administers the encryption key."
  type        = string
}

variable "dataset_prefix" {
  description = "Prefix for dataset files, for example datasets/email/v1/."
  type        = string
  default     = "datasets/email/v1/"
}

variable "metadata_prefix" {
  description = "Prefix for metadata files, for example metadata/email/v1/."
  type        = string
  default     = "metadata/email/v1/"
}

variable "reader_account_arns" {
  description = "Account root ARNs permitted to read the lake cross-account. The Development and Staging account roots for internal use, plus cross-government department roots once approved for sharing."
  type        = list(string)
  default     = []
}

variable "lakeformation_register_role_arn" {
  description = "ARN of an existing role Lake Formation uses to access the registered metadata location. Only used when create_lakeformation_register_role is false."
  type        = string
  default     = null
}

variable "create_lakeformation_register_role" {
  description = "Whether this module creates the Lake Formation registration role itself. False means lakeformation_register_role_arn must point to an existing role."
  type        = bool
  default     = true
}

variable "role_prefix" {
  description = "Prefix for IAM role names created by this module, e.g. 'gds-aidr'."
  type        = string
  default     = "gds-aidr"
}

variable "audit_log_retention_days" {
  description = "How long object-level audit logs are retained."
  type        = number
  default     = 365
}


variable "tags" {
  description = "Tags applied to all resources created by this module."
  type        = map(string)
  default     = {}
}
