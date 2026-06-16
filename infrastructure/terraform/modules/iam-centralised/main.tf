# iam-centralised/main.tf
#
# Creates the GitHub OIDC provider and IAM roles in a single target account.
# Called once per account (Development, Staging, Production) from the
# production-iam environment using provider aliases.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# --------------------------------------------------------------------------
# GitHub OIDC Identity Provider
# --------------------------------------------------------------------------
# This lets GitHub Actions authenticate to AWS without long-lived credentials.
# GitHub sends a signed JWT token; AWS validates it against this provider.
# One provider per account is required.

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = var.tags
}

# --------------------------------------------------------------------------
# Admin Role
# --------------------------------------------------------------------------
# Full AdministratorAccess. Only created if create_admin_role = true.
# Trust is restricted to specific named IAM user ARNs (not the broad account
# root), so only admins can assume it. MFA is always required.

resource "aws_iam_role" "admin" {
  count = var.create_admin_role ? 1 : 0

  name = "${var.role_prefix}-admin"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = var.admin_trusted_arns
        }
        Action = "sts:AssumeRole"
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      }
    ]
  })

  max_session_duration = var.max_session_duration

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "admin" {
  count = var.create_admin_role ? 1 : 0

  role       = aws_iam_role.admin[0].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# --------------------------------------------------------------------------
# Readonly Role
# --------------------------------------------------------------------------
# AWS-managed ReadOnlyAccess. For viewing resources, debugging, verifying
# deployments in CloudWatch, etc. Your contractor developer would use this for
# Staging and production. MFA required.

resource "aws_iam_role" "readonly" {
  count = var.create_readonly_role ? 1 : 0

  name = "${var.role_prefix}-readonly"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = var.trusted_account_arns
        }
        Action = "sts:AssumeRole"
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      }
    ]
  })

  max_session_duration = var.max_session_duration

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "readonly" {
  count = var.create_readonly_role ? 1 : 0

  role       = aws_iam_role.readonly[0].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# --------------------------------------------------------------------------
# Security Audit Role
# --------------------------------------------------------------------------
# AWS-managed SecurityAudit policy. Used by GDS Cyber Security team and
# automated scanning. Follows alphagov/cyber-security-shared-terraform-modules
# pattern.

resource "aws_iam_role" "security_audit" {
  count = var.create_security_audit_role ? 1 : 0

  name = "${var.role_prefix}-security-audit"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = var.trusted_account_arns
        }
        Action = "sts:AssumeRole"
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      }
    ]
  })

  max_session_duration = var.max_session_duration

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "security_audit" {
  count = var.create_security_audit_role ? 1 : 0

  role       = aws_iam_role.security_audit[0].name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

# --------------------------------------------------------------------------
# Terraform Role
# --------------------------------------------------------------------------
# Full AdministratorAccess, but trusted by BOTH humans (gds-users via MFA)
# and GitHub Actions (via OIDC). This is the role that plans and applies
# infrastructure changes. The OIDC subject condition locks it to specific
# repos and branches.

resource "aws_iam_role" "terraform" {
  count = var.create_terraform_role ? 1 : 0

  name = "${var.role_prefix}-terraform"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        # Human access via gds-users with MFA
        {
          Sid    = "AllowHumanAssumeWithMFA"
          Effect = "Allow"
          Principal = {
            AWS = var.trusted_account_arns
          }
          Action = "sts:AssumeRole"
          Condition = {
            Bool = {
              "aws:MultiFactorAuthPresent" = "true"
            }
          }
        },
        # GitHub Actions access via OIDC
        {
          Sid    = "AllowGitHubActionsOIDC"
          Effect = "Allow"
          Principal = {
            Federated = aws_iam_openid_connect_provider.github.arn
          }
          Action = "sts:AssumeRoleWithWebIdentity"
          Condition = {
            StringEquals = {
              "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            }
            StringLike = {
              "token.actions.githubusercontent.com:sub" = var.github_oidc_allowed_subjects
            }
          }
        }
      ],
      # Cross-account assume — only included when terraform_cross_account_arns
      # is non-empty. Avoids empty-principal error on accounts that do not
      # need cross-account trust (e.g. Production).
      length(var.terraform_cross_account_arns) > 0 ? [
        {
          Sid    = "AllowCrossAccountAssume"
          Effect = "Allow"
          Principal = {
            AWS = var.terraform_cross_account_arns
          }
          Action = "sts:AssumeRole"
        }
      ] : []
    )
  })
  max_session_duration = var.max_session_duration

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "terraform" {
  count = var.create_terraform_role ? 1 : 0

  role       = aws_iam_role.terraform[0].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# --------------------------------------------------------------------------
# Team Roles (data-scientist, developer, analyst, explorer)
# --------------------------------------------------------------------------
# This trust policy now uses named IAM user ARNs instead of account root.
#
# Before (trusted gds-users account root — anyone in gds-users could assume):
#   Principal = { AWS = var.trusted_account_arns }
#
# After (trusts only named users — constructed from allowed_users + account ID):
#   Principal = { AWS = [
#     "arn:aws:iam::<gds_users_account_id>:user/<username1>",
#     "arn:aws:iam::<gds_users_account_id>:user/<username2>",
#   ] }
#
# They are defined as a map in the calling environment, so
# adding a new role is one line — no module code changes needed.
#
# Each role has three fields:
#   full_access:         true = PowerUserAccess (full minus IAM writes)
#                        false = ReadOnlyAccess
#   allow_heavy_compute: true = no restrictions on Glue, SageMaker, etc.
#                        false = explicit deny on heavy compute services
#   allowed_users:       list of gds-users IAM usernames who may assume this role
#
# Trust: specific named users in gds-users with MFA required.

locals {
  team_roles = var.team_roles

  # Build a map of role_name => list of full IAM user ARNs
  # from the short usernames stored in SSM / passed via allowed_users.
  team_role_user_arns = {
    for role_name, role_config in var.team_roles : role_name => [
      for username in role_config.allowed_users :
      "arn:aws:iam::${var.gds_users_account_id}:user/${username}"
    ]
  }
}

# The role itself — one per entry in the map
resource "aws_iam_role" "team" {
  for_each = local.team_roles

  name = "${var.role_prefix}-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          # This was var.trusted_account_arns (account root)
          # Now uses named user ARNs from allowed_users
          AWS = local.team_role_user_arns[each.key]
        }
        Action = "sts:AssumeRole"
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      }
    ]
  })

  max_session_duration = var.max_session_duration

  tags = merge(var.tags, {
    RoleType = each.key
  })
}

# PowerUserAccess — attached to roles where full_access = true
resource "aws_iam_role_policy_attachment" "team_power" {
  for_each = { for k, v in local.team_roles : k => v if v.full_access }

  role       = aws_iam_role.team[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# ReadOnlyAccess — attached to roles where full_access = false
resource "aws_iam_role_policy_attachment" "team_readonly" {
  for_each = { for k, v in local.team_roles : k => v if !v.full_access }

  role       = aws_iam_role.team[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Deny heavy compute — attached to roles where allow_heavy_compute = false
resource "aws_iam_role_policy" "team_deny_heavy_compute" {
  for_each = { for k, v in local.team_roles : k => v if !v.allow_heavy_compute }

  name = "${var.role_prefix}-deny-heavy-compute"
  role = aws_iam_role.team[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyHeavyComputeServices"
        Effect = "Deny"
        Action = [
          "glue:*",
          "sagemaker:*",
          "bedrock:*",
          "elasticmapreduce:*",
          "redshift:*"
        ]
        Resource = "*"
      }
    ]
  })
}
