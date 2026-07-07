# workload-iam/variables.tf

variable "role_prefix" {
  description = "Prefix for all IAM role names, e.g. 'gds-aidr'."
  type        = string
  default     = "gds-aidr"
}

variable "workload_name" {
  description = "Name of the workload, e.g. 'synthetic-email-generation'. Used in role names."
  type        = string
}

variable "task_role_policy_json" {
  description = "Inline IAM policy JSON for the task role, granting the application's own runtime permissions. Null means no inline policy is attached."
  type        = string
  default     = null
}

variable "execution_role_secrets_arns" {
  description = "Secrets Manager ARNs the execution role may read to inject secrets at container start. Empty list means no secrets access is granted."
  type        = list(string)
  default     = []
}

variable "execution_role_kms_key_arns" {
  description = "KMS key ARNs needed to decrypt injected secrets. Empty list means no KMS decrypt access is granted."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to both roles."
  type        = map(string)
  default     = {}
}
