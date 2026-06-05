# iam-centralised/variables.tf

variable "role_prefix" {
  description = "Prefix for all IAM role names, e.g. 'gds-aidr'."
  type        = string
  default     = "gds-aidr"
}

variable "trusted_account_arns" {
  description = "List of AWS account root ARNs that can assume roles (typically the gds-users org root)."
  type        = list(string)
}

variable "admin_trusted_arns" {
  description = "List of specific IAM user ARNs that can assume the admin role. More restrictive than trusted_account_arns — only named individuals, not the whole account."
  type        = list(string)
  default     = []
}

variable "github_oidc_allowed_subjects" {
  description = "List of GitHub OIDC subject claims allowed to assume the terraform role. Format: 'repo:org/repo-name:ref:refs/heads/branch' or 'repo:org/repo-name:*' for any branch."
  type        = list(string)
  default     = []
}

variable "terraform_cross_account_arns" {
  description = "List of account root ARNs that can assume the terraform role without MFA. Used for cross-account Terraform provider aliases (e.g. production assuming into development)."
  type        = list(string)
  default     = []
}

variable "create_admin_role" {
  description = "Whether to create the admin role in this account."
  type        = bool
  default     = false
}

variable "create_readonly_role" {
  description = "Whether to create the readonly role in this account."
  type        = bool
  default     = true
}

variable "create_security_audit_role" {
  description = "Whether to create the security-audit role in this account."
  type        = bool
  default     = true
}

variable "create_terraform_role" {
  description = "Whether to create the terraform role (human + OIDC) in this account."
  type        = bool
  default     = true
}

variable "team_roles" {
  description = <<-EOT
    Map of team roles to create. Each entry creates a role named
    {role_prefix}-{key} with configurable permissions.

    full_access:         true = PowerUserAccess (full minus IAM writes)
                         false = ReadOnlyAccess
    allow_heavy_compute: true = no deny on Glue, SageMaker, Bedrock, EMR, Redshift
                         false = explicit deny on these services

    Example:
      team_roles = {
        data-scientist = { full_access = true,  allow_heavy_compute = true }
        developer      = { full_access = true,  allow_heavy_compute = false }
        analyst        = { full_access = false, allow_heavy_compute = false }
        explorer       = { full_access = false, allow_heavy_compute = false }
      }
  EOT
  type = map(object({
    full_access         = bool
    allow_heavy_compute = bool
  }))
  default = {}
}

variable "max_session_duration" {
  description = "Maximum session duration in seconds when assuming roles. 14400 = 4 hours."
  type        = number
  default     = 14400
}

variable "tags" {
  description = "Tags applied to all resources created by this module."
  type        = map(string)
  default     = {}
}
