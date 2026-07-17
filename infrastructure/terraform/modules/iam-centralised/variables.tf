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

variable "chained_trusted_account_arns" {
  description = "Account root ARNs allowed to assume the terraform role via cross-account chaining, e.g. the production account root so it can chain into development and staging without a bootstrap role."
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

variable "team_roles" {
  description = <<-EOT
    Map of team roles to create. Each role specifies:
      - full_access:         true = PowerUserAccess, false = ReadOnlyAccess
      - allow_heavy_compute: true = no restrictions, false = deny Glue/SageMaker/EMR/Redshift
      - deployment_mode:     "full" = no restrictions
                             "app_only" = allows ECR, ECS task/service ops, Lambda, Cognito;
                                          blocks VPC, EC2, CloudFormation, ECS cluster creation,
                                          networking, CI/CD pipelines, Terraform state, SSM role assignments
                             "none" = deny all deployment services
      - allowed_users:       list of gds-users IAM usernames who may assume this role

    Example:
      team_roles = {
        developer = {
          full_access         = true
          allow_heavy_compute = true
          deployment_mode     = "app_only"
          allowed_users       = ["firstname1.surname1"]
        }
      }
  EOT
  type = map(object({
    full_access         = bool
    allow_heavy_compute = bool
    deployment_mode     = string
    # allow_deployment    = bool  # Replaced by deployment_mode 14 July 2026
    allowed_users = list(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.team_roles : contains(["full", "app_only", "none"], v.deployment_mode)
    ])
    error_message = "deployment_mode must be one of: full, app_only, none"
  }
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

variable "create_ci_push_role" {
  description = "Whether to create one shared CI push role for this account, trusted for any alphagov repo using the configured GitHub Environment. Not per-app — onboarding a new app needs no infra change to this role."
  type        = bool
  default     = false
}

variable "create_ci_apply_role" {
  description = "Whether to create one shared CI apply role for this account, trusted for any alphagov repo using the configured GitHub Environment. Not per-app — onboarding a new app needs no infra change to this role."
  type        = bool
  default     = false
}

variable "ci_github_org" {
  description = "GitHub org repos must belong to, e.g. 'alphagov'."
  type        = string
  default     = "alphagov"
}

variable "ci_github_environment" {
  description = "GitHub Environment name a repo's workflow must run under to assume this role. Configured per-repo in that repo's own GitHub settings — never needs an infra change."
  type        = string
  default     = "aidr-deploy"
}

variable "workload_role_account_id" {
  description = "Account ID where workload-iam roles live, for the CI apply role's PassRole scoping. Development, since that's where ECS tasks currently run."
  type        = string
  default     = null
}

# --------------------------------------------------------------------------
# Data reader role for synthetic data engine
# --------------------------------------------------------------------------


# variable "create_data_reader_role" {
#  description = "Whether to create the scoped data-reader role in this account."
#  type        = bool
#  default     = false
#}

#variable "data_reader_trusted_arns" {
#  description = "List of account root ARNs that can assume the data-reader role. The gds-users org root for internal use, plus cross-government department account roots for cross-government use."
#  type        = list(string)
#  default     = []
#}

#variable "data_lake_bucket_arn" {
#  description = "ARN of the data lake bucket the data-reader role reads from."
#  type        = string
#  default     = ""
#}

#variable "dataset_prefix" {
#  description = "Prefix for dataset files the data-reader role may read, for example datasets/email/v1/."
#  type        = string
#  default     = ""
#}

#variable "metadata_prefix" {
#  description = "Prefix for metadata files the data-reader role may read, for example metadata/email/v1/."
#  type        = string
#  default     = ""
#}
