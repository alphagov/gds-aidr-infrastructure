# cloudtrail-digest/variables.tf

variable "role_prefix" {
  description = "Prefix for all resource names, e.g. 'gds-aidr'."
  type        = string
  default     = "gds-aidr"
}

variable "account_label" {
  description = "Human-readable account name (e.g. 'Development', 'Staging', 'Production'). Used in the digest subject line and Lambda function name."
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic to publish the digest to. This topic lives in the Production account."
  type        = string
}

variable "log_retention_days" {
  description = "Number of days to retain Lambda CloudWatch logs."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags applied to all resources created by this module."
  type        = map(string)
  default     = {}
}
