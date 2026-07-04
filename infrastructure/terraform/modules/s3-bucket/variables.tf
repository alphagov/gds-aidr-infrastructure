# s3-bucket/variables.tf

variable "environment_name" {
  description = "Snake Case environment name used in resource Name tags, e.g. Production."
  type        = string
}

variable "bucket_name" {
  description = "Name of the S3 bucket."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for bucket encryption. Required — no unencrypted buckets."
  type        = string
}

variable "versioning_enabled" {
  description = "Whether object versioning is enabled."
  type        = bool
  default     = true
}

variable "prefixes" {
  description = "List of prefixes to create as zero-byte placeholder objects, e.g. [\"datasets\", \"metadata\"]."
  type        = list(string)
  default     = []
}

variable "noncurrent_version_expiration_days" {
  description = "Days after which noncurrent object versions expire. Null disables this rule."
  type        = number
  default     = null
}

variable "abort_incomplete_multipart_upload_days" {
  description = "Days after which incomplete multipart uploads are aborted. Null disables this rule."
  type        = number
  default     = 7
}

variable "bucket_policy_json" {
  description = "Bucket policy document as JSON. Null means no policy is attached."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to the bucket."
  type        = map(string)
  default     = {}
}
