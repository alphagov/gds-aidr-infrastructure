# ecr/variables.tf

variable "environment_name" {
  description = "Snake Case environment name used in resource Name tags, e.g. Development."
  type        = string
}

variable "repository_name" {
  description = "Name of the ECR repository."
  type        = string
}

variable "image_tag_mutability" {
  description = "Whether image tags can be overwritten. IMMUTABLE prevents a tag being pushed twice with different content."
  type        = string
  default     = "IMMUTABLE"
}

variable "scan_on_push" {
  description = "Whether to run an image vulnerability scan automatically on every push."
  type        = bool
  default     = true
}

variable "untagged_image_expiry_days" {
  description = "Number of days after which untagged images are expired by the lifecycle policy."
  type        = number
  default     = 14
}

variable "kms_key_arn" {
  description = "KMS key ARN for repository encryption. Null uses the AWS-managed AES256 default."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to the repository."
  type        = map(string)
  default     = {}
}
