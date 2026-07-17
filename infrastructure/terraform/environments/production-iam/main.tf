# environments/production-iam/main.tf
#
# Centralised IAM management. This Terraform runs in the Production account and
# creates OIDC providers + IAM roles in all three accounts (Development, Staging, Production).
#
# Why centralised: one state file, one place to see all roles, no drift
# between environments. Changes to IAM go through a single PR.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # STATE BUCKET
  backend "s3" {
    bucket       = "gds-aidr-terraform-state-production"
    key          = "production-iam/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}


# --------------------------------------------------------------------------
# Provider: Production (default — no alias needed)
# --------------------------------------------------------------------------
provider "aws" {
  region = "eu-west-2"

  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Team        = "gds-aidr"
      Environment = "production"
      Repository  = "alphagov/gds-aidr-infrastructure"
    }
  }
}

# --------------------------------------------------------------------------
# Provider: Development (assumes into the Development account)
# --------------------------------------------------------------------------

provider "aws" {
  alias  = "development"
  region = "eu-west-2"

  assume_role {
    role_arn     = "arn:aws:iam::${var.development_account_id}:role/gds-aidr-terraform"
    session_name = "production-iam-terraform"
  }

  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Team        = "gds-aidr"
      Environment = "development"
      Repository  = "alphagov/gds-aidr-infrastructure"
    }
  }
}

# --------------------------------------------------------------------------
# Provider: Staging (assumes into the Staging account)
# --------------------------------------------------------------------------

provider "aws" {
  alias  = "staging"
  region = "eu-west-2"

  assume_role {
    role_arn     = "arn:aws:iam::${var.staging_account_id}:role/gds-aidr-terraform"
    session_name = "production-iam-terraform"
  }

  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Team        = "gds-aidr"
      Environment = "staging"
      Repository  = "alphagov/gds-aidr-infrastructure"
    }
  }
}

# --------------------------------------------------------------------------
# SSM Parameter: team role assignments
# --------------------------------------------------------------------------
# Reads the user-to-role mapping from SSM Parameter Store.
# The parameter is a SecureString containing JSON like:
#   {
#     "data-scientist": ["victoria.mckinney", "an.nguyen", "piers.walker"],
#     "developer": ["victoria.mckinney", "an.nguyen"],
#     ...
#   }
#
# This keeps all personal data out of the public repository.
# To update who has access: update the SSM parameter, then terraform apply.

data "aws_ssm_parameter" "team_role_assignments" {
  name            = "/gds-aidr/iam/team-role-assignments"
  with_decryption = true
}

locals {
  # Decode the JSON from SSM into a Terraform map
  # Result: { "data-scientist" = ["firstname.surname", ...], ... }
  team_role_assignments = jsondecode(data.aws_ssm_parameter.team_role_assignments.value)
}

# --------------------------------------------------------------------------
# Module: IAM for Development account
# --------------------------------------------------------------------------
# Admin role enabled — this is the sandbox account. Your contractor developer
# gets readonly access via the readonly role.
# Team roles: data-scientist gets full access + heavy compute.
# Developer gets full access but no heavy compute.
# Analyst and explorer get read-only.

module "iam_development" {
  source = "../../modules/iam-centralised"

  providers = {
    aws = aws.development
  }

  role_prefix          = var.role_prefix
  trusted_account_arns = [var.gds_users_account_arn]
  gds_users_account_id = var.gds_users_account_id

  admin_trusted_arns = var.admin_trusted_arns

  create_admin_role          = true
  create_readonly_role       = true
  create_security_audit_role = true
  create_terraform_role      = true
  create_ci_push_role        = true

  terraform_cross_account_arns = ["arn:aws:iam::${var.production_account_id}:root"]

  # Team roles with allowed_users from SSM.
  # Data-scientist gets full access + heavy compute, all deployment blocked.
  # Developer gets full access + heavy compute, app deployment allowed (ECR, ECS, Lambda, Cognito),
  #   infrastructure deployment blocked (VPC, EC2, CloudFormation, etc.).
  # Analyst and explorer get read-only, heavy compute denied, all deployment blocked.
  team_roles = {
    data-scientist = {
      full_access         = true
      allow_heavy_compute = true
      deployment_mode     = "none"
      allowed_users       = local.team_role_assignments["data-scientist"]
    }
    developer = {
      full_access         = true
      allow_heavy_compute = true
      deployment_mode     = "app_only"
      allowed_users       = local.team_role_assignments["developer"]
    }
    analyst = {
      full_access         = false
      allow_heavy_compute = false
      deployment_mode     = "none"
      allowed_users       = local.team_role_assignments["analyst"]
    }
    explorer = {
      full_access         = false
      allow_heavy_compute = false
      deployment_mode     = "none"
      allowed_users       = local.team_role_assignments["explorer"]
    }
  }

  github_oidc_allowed_subjects = var.github_oidc_allowed_subjects
  chained_trusted_account_arns = ["arn:aws:iam::${var.production_account_id}:root"]


  max_session_duration = var.max_session_duration

  tags = {
    Environment = "development"
    AccountId   = var.development_account_id
  }
}

# --------------------------------------------------------------------------
# Module: IAM for Staging account
# --------------------------------------------------------------------------
# No admin role — Staging is a pre-Production mirror. Changes go through
# Terraform only. All team roles are read-only with heavy compute denied.

module "iam_staging" {
  source = "../../modules/iam-centralised"

  providers = {
    aws = aws.staging
  }

  role_prefix          = var.role_prefix
  trusted_account_arns = [var.gds_users_account_arn]
  gds_users_account_id = var.gds_users_account_id

  admin_trusted_arns = var.admin_trusted_arns

  create_admin_role          = false
  create_readonly_role       = true
  create_security_audit_role = true
  create_terraform_role      = true

  terraform_cross_account_arns = ["arn:aws:iam::${var.production_account_id}:root"]

  # All roles are read-only in Staging with heavy compute and deployment denied.
  team_roles = {
    data-scientist = {
      full_access         = false
      allow_heavy_compute = false
      deployment_mode     = "none"
      allowed_users       = local.team_role_assignments["data-scientist"]
    }
    developer = {
      full_access         = false
      allow_heavy_compute = false
      deployment_mode     = "none"
      allowed_users       = local.team_role_assignments["developer"]
    }
    analyst = {
      full_access         = false
      allow_heavy_compute = false
      deployment_mode     = "none"
      allowed_users       = local.team_role_assignments["analyst"]
    }
    explorer = {
      full_access         = false
      allow_heavy_compute = false
      deployment_mode     = "none"
      allowed_users       = local.team_role_assignments["explorer"]
    }
  }

  github_oidc_allowed_subjects = var.github_oidc_allowed_subjects
  chained_trusted_account_arns = ["arn:aws:iam::${var.production_account_id}:root"]


  max_session_duration = var.max_session_duration

  tags = {
    Environment = "staging"
    AccountId   = var.staging_account_id
  }
}

# --------------------------------------------------------------------------
# Module: IAM for Production account
# --------------------------------------------------------------------------
# Admin role enabled but restricted to named users only (admins).
# All team roles are read-only with heavy compute denied.

module "iam_production" {
  source = "../../modules/iam-centralised"

  # No provider alias — uses the default (production) provider.

  role_prefix          = var.role_prefix
  trusted_account_arns = [var.gds_users_account_arn]
  gds_users_account_id = var.gds_users_account_id

  admin_trusted_arns = var.admin_trusted_arns

  create_admin_role          = true
  create_readonly_role       = true
  create_security_audit_role = true
  create_terraform_role      = true
  create_ci_apply_role       = true
  workload_role_account_id   = var.development_account_id

  # Enable the data-reader role in Production
  # create_data_reader_role  = true
  # data_reader_trusted_arns = var.data_reader_trusted_arns

  # All roles are read-only in Production with heavy compute and deployment denied.
  team_roles = {
    data-scientist = {
      full_access         = false
      allow_heavy_compute = false
      deployment_mode     = "none"
      allowed_users       = local.team_role_assignments["data-scientist"]
    }
    developer = {
      full_access         = false
      allow_heavy_compute = false
      deployment_mode     = "none"
      allowed_users       = local.team_role_assignments["developer"]
    }
    analyst = {
      full_access         = false
      allow_heavy_compute = false
      deployment_mode     = "none"
      allowed_users       = local.team_role_assignments["analyst"]
    }
    explorer = {
      full_access         = false
      allow_heavy_compute = false
      deployment_mode     = "none"
      allowed_users       = local.team_role_assignments["explorer"]
    }
  }

  github_oidc_allowed_subjects = var.github_oidc_allowed_subjects

  max_session_duration = var.max_session_duration

  tags = {
    Environment = "production"
    AccountId   = var.production_account_id
  }
}

# --------------------------------------------------------------------------
# Budget Alerts
# --------------------------------------------------------------------------
# Monthly cost budgets per account. Alert thresholds at 50%, 80%, 100%
# actual spend, plus 100% forecasted. Emails go to platform admins.
# Budget limits are set in terraform.tfvars.

module "budget_development" {
  source = "../../modules/budget-alerts"

  providers = {
    aws = aws.development
  }

  budget_prefix     = "gds-aidr-development"
  monthly_limit_usd = var.budget_development_usd
  alert_emails      = var.budget_alert_emails

  tags = {
    Environment = "development"
    AccountId   = var.development_account_id
  }
}

module "budget_staging" {
  source = "../../modules/budget-alerts"

  providers = {
    aws = aws.staging
  }

  budget_prefix     = "gds-aidr-staging"
  monthly_limit_usd = var.budget_staging_usd
  alert_emails      = var.budget_alert_emails

  tags = {
    Environment = "staging"
    AccountId   = var.staging_account_id
  }
}

module "budget_production" {
  source = "../../modules/budget-alerts"

  # No provider alias — uses the default (Production) provider.

  budget_prefix     = "gds-aidr-production"
  monthly_limit_usd = var.budget_production_usd
  alert_emails      = var.budget_alert_emails

  tags = {
    Environment = "production"
    AccountId   = var.production_account_id
  }
}
