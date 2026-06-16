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

# --------------------------------------------------------------------------
# gds-users account ID for constructing user ARNs
# --------------------------------------------------------------------------
# Used by team role trust policies to build ARNs from the usernames stored
# in SSM Parameter Store. Kept as a separate variable (not derived from
# trusted_account_arns) because trusted_account_arns contains the full
# root ARN and may include multiple entries in future.

variable "gds_users_account_id" {
  description = "AWS account ID of the gds-users organisation root account. Used to construct IAM user ARNs for team role trust policies."
  type        = string
}

variable "github_oidc_allowed_subjects" {
  description = "List of GitHub OIDC subject claims allowed to assume the terraform role. Format: 'repo:org/repo-name:ref:refs/heads/branch' or 'repo:org/repo-name:*' for any branch."
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

# --------------------------------------------------------------------------
# Team roles
# --------------------------------------------------------------------------
# UPDATED MON-15-JUNE-2026 added allowed_users field to the object type.
# UPDATED MON-16-JUNE-2026 added allow_deployment field to the object type.
#
# Changelog:
#   team_roles = map(object({
#     full_access         = bool
#     allow_heavy_compute = bool
#   }))
#   → added allowed_users (15 June 2026)
#   → added allow_deployment (16 June 2026)
#
# allowed_users contains gds-users IAM usernames (not full ARNs).
# The module constructs full ARNs using gds_users_account_id.

variable "team_roles" {
  description = <<-EOT
    Map of team roles to create. Each role specifies:
      - full_access:         true = PowerUserAccess, false = ReadOnlyAccess
      - allow_heavy_compute: true = no restrictions, false = deny Glue/SageMaker/Bedrock/EMR/Redshift
      - allow_deployment:    true = no restrictions, false = deny VPC/EC2/ECS/EKS/Lambda/ALB/CloudFormation/CI-CD
      - allowed_users:       list of gds-users IAM usernames who may assume this role

    Example:
      team_roles = {
        data-scientist = {
          full_access         = true
          allow_heavy_compute = true
          allow_deployment    = false
          allowed_users       = ["victoria.mckinney", "an.nguyen", "piers.walker"]
        }
      }
  EOT
  type = map(object({
    full_access         = bool
    allow_heavy_compute = bool
    allow_deployment    = bool
    allowed_users       = list(string)
  }))
  default = {}
}

variable "terraform_cross_account_arns" {
  description = "Additional account root ARNs that can assume the terraform role (for cross-account Terraform runs)."
  type        = list(string)
  default     = []
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
