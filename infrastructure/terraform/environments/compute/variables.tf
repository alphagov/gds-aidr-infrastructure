# environments/compute/variables.tf

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
  description = "Prefix for IAM role and resource names, used to reference the existing terraform role created by production-iam."
  type        = string
  default     = "gds-aidr"
}

variable "synthetic_email_generation_container_port" {
  description = "Port the synthetic-email-generation container listens on for HTTP traffic."
  type        = number
  default     = 8080
}

variable "synthetic_email_generation_health_check_path" {
  description = "Path the ALB polls to check the synthetic-email-generation container's health."
  type        = string
  default     = "/health"
}
