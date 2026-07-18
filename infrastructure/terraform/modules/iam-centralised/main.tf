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

locals {
  # Base trust statements, always present.
  terraform_role_base_statements = [
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
  ]

  # Chaining statement, only added when chained_trusted_account_arns is set.
  # No MFA condition here — MFA is not propagated through role chaining, so
  # requiring it would block legitimate chained sessions that already passed
  # MFA on the first hop.
  terraform_role_chaining_statement = length(var.chained_trusted_account_arns) > 0 ? [
    {
      Sid    = "AllowChainedAssumeFromTrustedAccounts"
      Effect = "Allow"
      Principal = {
        AWS = var.chained_trusted_account_arns
      }
      Action = "sts:AssumeRole"
    }
  ] : []

  terraform_role_statements = concat(
    local.terraform_role_base_statements,
    local.terraform_role_chaining_statement
  )
}

resource "aws_iam_role" "terraform" {
  count = var.create_terraform_role ? 1 : 0

  name = "${var.role_prefix}-terraform"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.terraform_role_statements
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
# Each role has four fields:
#   full_access:         true = PowerUserAccess (full minus IAM writes)
#                        false = ReadOnlyAccess
#   allow_heavy_compute: true = no restrictions on Glue, SageMaker, etc.
#                        false = explicit deny on heavy compute services
#   deployment_mode:     "full" = no deployment restrictions
#                        "app_only" = blocks infrastructure (VPC, EC2, CloudFormation, etc.)
#                                     allows application deployment (ECR, ECS services, Lambda, Cognito)
#                                     protects Terraform state and SSM role assignments
#                        "none" = blocks all deployment services
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
          "elasticmapreduce:*",
          "redshift:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# Deny ALL deployment services — attached to roles where deployment_mode = "none".
# Blocks creating or launching any infrastructure or application workloads.
# Read-only access to these services is unaffected (users can still view resources
# in the console and CloudWatch). Data services (S3, Athena, etc.) are unaffected.
# Used for Staging and Production where all team roles are read-only.
resource "aws_iam_role_policy" "team_deny_deployment" {
  for_each = { for k, v in local.team_roles : k => v if v.deployment_mode == "none" }

  name = "${var.role_prefix}-deny-deployment"
  role = aws_iam_role.team[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyDeploymentServices"
        Effect = "Deny"
        Action = [
          # VPC and networking
          "ec2:RunInstances",
          "ec2:CreateVpc",
          "ec2:CreateSubnet",
          "ec2:CreateSecurityGroup",
          "ec2:CreateNatGateway",
          "ec2:CreateInternetGateway",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateRouteTable",
          "ec2:CreateRoute",
          # Containers
          "ecs:CreateCluster",
          "ecs:CreateService",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService",
          "ecs:RunTask",
          "ecs:StartTask",
          "eks:CreateCluster",
          "eks:CreateNodegroup",
          # Serverless
          "lambda:CreateFunction",
          "lambda:UpdateFunctionCode",
          "lambda:PublishVersion",
          # Load balancing and autoscaling
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup",
          "autoscaling:CreateAutoScalingGroup",
          "autoscaling:CreateLaunchConfiguration",
          # Infrastructure as code
          "cloudformation:CreateStack",
          "cloudformation:UpdateStack",
          # CI/CD and deployment services
          "codedeploy:*",
          "codepipeline:*",
          "codebuild:*",
          # Application hosting
          "elasticbeanstalk:Create*",
          "elasticbeanstalk:Update*",
          "apprunner:*",
          # ECR write
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          # Cognito write
          "cognito-idp:Create*",
          "cognito-idp:Update*",
          "cognito-idp:Delete*",
          "cognito-idp:AdminCreate*",
          "cognito-idp:AdminUpdate*",
          "cognito-idp:AdminDelete*"
        ]
        Resource = "*"
      }
    ]
  })
}

# Deny INFRASTRUCTURE deployment only — attached to roles where deployment_mode = "app_only".
# Blocks creating VPCs, EC2 instances, ECS clusters, CloudFormation stacks, networking,
# and CI/CD pipelines. Allows application-level deployment: ECR push/pull, ECS service
# updates, ECS task runs, Lambda functions, Cognito user pools, CloudWatch log groups.
# Used for the developer role in Development where application deployment is needed
# but infrastructure changes must go through Terraform.
resource "aws_iam_role_policy" "team_deny_infra_deployment" {
  for_each = { for k, v in local.team_roles : k => v if v.deployment_mode == "app_only" }

  name = "${var.role_prefix}-deny-infra-deployment"
  role = aws_iam_role.team[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyInfrastructureDeployment"
        Effect = "Deny"
        Action = [
          # VPC and networking — never via console/CLI
          "ec2:RunInstances",
          "ec2:CreateVpc",
          "ec2:CreateSubnet",
          "ec2:CreateSecurityGroup",
          "ec2:CreateNatGateway",
          "ec2:CreateInternetGateway",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateRouteTable",
          "ec2:CreateRoute",
          "ec2:DeleteVpc",
          "ec2:DeleteSubnet",
          "ec2:DeleteSecurityGroup",
          "ec2:DeleteNatGateway",
          "ec2:DeleteInternetGateway",
          "ec2:DeleteRouteTable",
          "ec2:DeleteRoute",
          "ec2:ModifyVpcAttribute",
          "ec2:ModifySubnetAttribute",
          # ECS cluster management — use the existing cluster, do not create new ones
          "ecs:CreateCluster",
          "ecs:DeleteCluster",
          # EKS — not used on this platform
          "eks:CreateCluster",
          "eks:CreateNodegroup",
          "eks:DeleteCluster",
          "eks:DeleteNodegroup",
          # Load balancing and autoscaling — infrastructure, not application
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:DeleteTargetGroup",
          "autoscaling:CreateAutoScalingGroup",
          "autoscaling:DeleteAutoScalingGroup",
          "autoscaling:CreateLaunchConfiguration",
          # Infrastructure as code — all infra changes go through Terraform
          "cloudformation:*",
          # CI/CD pipelines — managed by platform admin
          "codedeploy:*",
          "codepipeline:*",
          "codebuild:*",
          # Application hosting platforms — not used on this platform
          "elasticbeanstalk:*",
          "apprunner:*",
          # IAM — infrastructure, never via console/CLI
          "iam:Create*",
          "iam:Delete*",
          "iam:Put*",
          "iam:Attach*",
          "iam:Detach*",
          "iam:Update*"
        ]
        Resource = "*"
      },
      # Protect Terraform state buckets
      {
        Sid    = "DenyTerraformStateBucketAccess"
        Effect = "Deny"
        Action = [
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObject"
        ]
        Resource = [
          "arn:aws:s3:::gds-aidr-terraform-state-*/*"
        ]
      },
      # Protect SSM Parameter Store role assignments
      {
        Sid    = "DenySSMRoleAssignmentsWrite"
        Effect = "Deny"
        Action = [
          "ssm:PutParameter",
          "ssm:DeleteParameter"
        ]
        Resource = [
          "arn:aws:ssm:*:*:parameter/gds-aidr/iam/*"
        ]
      }
    ]
  })
}
# --------------------------------------------------------------------------
# CI push role
# --------------------------------------------------------------------------
# One shared role, trusted for any alphagov repo running under the
# ci_github_environment GitHub Environment — not tied to a branch name and
# not per-app. Onboarding a new app needs its ECR repo created (containers
# environment), but never needs this role touching again.

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "ci_push" {
  count = var.create_ci_push_role ? 1 : 0

  name = "${var.role_prefix}-ci-push"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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
            "token.actions.githubusercontent.com:sub" = "repo:${var.ci_github_org}/*:environment:${var.ci_github_environment}"
          }
        }
      }
    ]
  })

  max_session_duration = var.max_session_duration
  tags                 = var.tags
}

resource "aws_iam_role_policy" "ci_push" {
  count = var.create_ci_push_role ? 1 : 0

  name = "${var.role_prefix}-ci-push"
  role = aws_iam_role.ci_push[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        # Any ECR repo in this account. The account boundary is already the
        # real security boundary here — only this team's approved repos
        # exist in it, all created via the containers environment.
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:BatchGetImage"
        ]
        Resource = "arn:aws:ecr:eu-west-2:${data.aws_caller_identity.current.account_id}:repository/*"
      }
    ]
  })
}

# --------------------------------------------------------------------------
# CI apply role
# --------------------------------------------------------------------------
# Same trust pattern as the push role. PassRole is wildcarded against the
# existing gds-aidr-{app}-execution / gds-aidr-{app}-task naming convention
# already used by every workload-iam call — no per-app entry needed.

resource "aws_iam_role" "ci_apply" {
  count = var.create_ci_apply_role ? 1 : 0

  name = "${var.role_prefix}-ci-apply"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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
            "token.actions.githubusercontent.com:sub" = "repo:${var.ci_github_org}/*:environment:${var.ci_github_environment}"
          }
        }
      }
    ]
  })

  max_session_duration = var.max_session_duration
  tags                 = var.tags
}

resource "aws_iam_role_policy" "ci_apply" {
  count = var.create_ci_apply_role ? 1 : 0

  name = "${var.role_prefix}-ci-apply"
  role = aws_iam_role.ci_apply[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # compute state: read and write. networking/containers state: read
        # only, needed because the compute environment reads their outputs
        # via terraform_remote_state — those reads always run as this role,
        # not as whichever account's provider alias is active.
        Sid    = "TerraformStateAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::gds-aidr-terraform-state-production",
          "arn:aws:s3:::gds-aidr-terraform-state-production/compute/*",
          "arn:aws:s3:::gds-aidr-terraform-state-production/networking/*",
          "arn:aws:s3:::gds-aidr-terraform-state-production/containers/*"
        ]
      },
      {
        # Production only — resources here are managed directly as this
        # role, no chaining. Development and Staging resources go through
        # the chained gds-aidr-terraform assume below instead.
        Sid    = "ECSDeploy"
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:DescribeClusters",
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition",
          "ecs:DeregisterTaskDefinition"
        ]
        Resource = "*"
      },
      {
        Sid    = "ReadWorkloadRoles"
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies"
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.role_prefix}-*-execution",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.role_prefix}-*-task"
        ]
      },
      {
        Sid    = "PassRoleToWorkloadRoles"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = [
          "arn:aws:iam::${var.workload_role_account_id}:role/${var.role_prefix}-*-execution",
          "arn:aws:iam::${var.workload_role_account_id}:role/${var.role_prefix}-*-task",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.role_prefix}-*-execution",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.role_prefix}-*-task"
        ]
      },
      {
        # Lets ci-apply chain into the existing admin terraform role in
        # Development and Staging, same mechanism the human terraform role
        # already uses for cross-account applies — not new trust, just the
        # matching permission on this role's own policy.
        Sid    = "AssumeTerraformRoleInOtherAccounts"
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = [
          "arn:aws:iam::${var.workload_role_account_id}:role/${var.role_prefix}-terraform",
          "arn:aws:iam::${var.staging_account_id}:role/${var.role_prefix}-terraform"
        ]
      }
    ]
  })
}

# --------------------------------------------------------------------------
# Data Reader Role
# --------------------------------------------------------------------------
# Trusted by the accounts in data_reader_trusted_arns. For internal use this is
# the gds-users org root. For cross-government use this is the other
# department's account root, added to the same list. MFA is always required.

#resource "aws_iam_role" "data_reader" {
# count = var.create_data_reader_role ? 1 : 0

#name = "${var.role_prefix}-data-reader"

#  assume_role_policy = jsonencode({
#    Version = "2012-10-17"
#    Statement = [
#      {
#        Effect = "Allow"
#        Principal = {
#          AWS = var.data_reader_trusted_arns
#        }
#        Action = "sts:AssumeRole"
#        Condition = {
#          Bool = {
#            "aws:MultiFactorAuthPresent" = "true"
#          }
#        }
#     }
#    ]
#  })
#
#  max_session_duration = var.max_session_duration
#
#  tags = var.tags
#}

# Read access scoped to the dataset and metadata prefixes of the data lake
# bucket. ListBucket is scoped with a condition so a caller can only list the
# permitted prefixes, not the whole bucket.

#resource "aws_iam_role_policy" "data_reader" {
#  count = var.create_data_reader_role ? 1 : 0
#
#  name = "${var.role_prefix}-data-reader"
#  role = aws_iam_role.data_reader[0].id
#
#  policy = jsonencode({
#    Version = "2012-10-17"
#    Statement = [
#      {
#        Sid    = "ReadObjects"
#        Effect = "Allow"
#        Action = [
#          "s3:GetObject"
#        ]
#        Resource = [
#          "${var.data_lake_bucket_arn}/${var.dataset_prefix}*",
#          "${var.data_lake_bucket_arn}/${var.metadata_prefix}*"
#        ]
#      },
#      {
#        Sid    = "ListPermittedPrefixes"
#        Effect = "Allow"
#        Action = [
#          "s3:ListBucket"
#        ]
#        Resource = var.data_lake_bucket_arn
#        Condition = {
#          StringLike = {
#            "s3:prefix" = [
#              "${var.dataset_prefix}*",
#              "${var.metadata_prefix}*"
#            ]
#          }
#        }
#      }
#    ]
#  })
#}
