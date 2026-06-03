# iam-centralised/main.tf
#
# Creates the GitHub OIDC provider and IAM roles in a single target account.
# Called once per account (development, staging, production) from the
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
# root), so admins can assume it. MFA is always required.

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
# deployments in CloudWatch, etc. Develop[ers would use this for
# Staging and Production. MFA required.

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
#
# When terraform_cross_account_arns is non-empty, a third trust statement
# is added to allow the production account to assume this role directly.
# This is needed because chained assume-role calls (gds-users → production
# → development) do not carry the original gds-users identity, so the
# production account root must be explicitly trusted.

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
      # Cross-account access — only included when the list is non-empty.
      # This allows the production account to assume into development and
      # staging terraform roles during centralised Terraform runs.
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
# Data User Role
# --------------------------------------------------------------------------
# For data scientists, data engineers, analysts, and anyone who needs
# hands-on access to AWS data services.
#
# Permissions vary by environment:
#   - Development: PowerUserAccess (full minus IAM writes), heavy compute
#     services allowed (Glue, SageMaker, Bedrock, EMR, Redshift).
#   - Staging/Production: ReadOnlyAccess only, heavy compute services
#     explicitly denied as belt-and-braces.
#
# Controlled by two variables:
#   - data_user_full_access: true = PowerUserAccess, false = ReadOnlyAccess
#   - data_user_allow_heavy_compute: true = no deny, false = deny policy attached
#
# Trust: gds-users account root with MFA. Anyone in gds-users can assume
# this role without being individually named.

resource "aws_iam_role" "data_user" {
  count = var.create_data_user_role ? 1 : 0

  name = "${var.role_prefix}-data-user"

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

# Attach PowerUserAccess in development (full minus IAM writes)
resource "aws_iam_role_policy_attachment" "data_user_power" {
  count = var.create_data_user_role && var.data_user_full_access ? 1 : 0

  role       = aws_iam_role.data_user[0].name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# Attach ReadOnlyAccess in staging and production
resource "aws_iam_role_policy_attachment" "data_user_readonly" {
  count = var.create_data_user_role && !var.data_user_full_access ? 1 : 0

  role       = aws_iam_role.data_user[0].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Deny heavy compute services in staging and production.
# Belt-and-braces: ReadOnlyAccess already blocks writes, but this makes
# the intent explicit and protects against future permission changes.
resource "aws_iam_role_policy" "data_user_deny_heavy_compute" {
  count = var.create_data_user_role && !var.data_user_allow_heavy_compute ? 1 : 0

  name = "${var.role_prefix}-deny-heavy-compute"
  role = aws_iam_role.data_user[0].name

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
