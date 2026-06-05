# environments/production-iam/main.tf
#
# Centralised IAM management. This Terraform runs in the production account and
# creates OIDC providers + IAM roles in all three accounts Development, Staging, Production).
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
# Provider: Development (assumes into the development account)
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
# Provider: Staging (assumes into the staging account)
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

# ==========================================================================
# IAM ROLES
# ==========================================================================

# --------------------------------------------------------------------------
# Module: IAM for Development account
# --------------------------------------------------------------------------
# Admin role enabled — this is the experimentation account.
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

  admin_trusted_arns = var.admin_trusted_arns

  create_admin_role          = true
  create_readonly_role       = true
  create_security_audit_role = true
  create_terraform_role      = true

  terraform_cross_account_arns = ["arn:aws:iam::${var.production_account_id}:root"]

  team_roles = {
    data-scientist = { full_access = true, allow_heavy_compute = true }
    developer      = { full_access = true, allow_heavy_compute = false }
    analyst        = { full_access = false, allow_heavy_compute = false }
    explorer       = { full_access = false, allow_heavy_compute = false }
  }

  github_oidc_allowed_subjects = var.github_oidc_allowed_subjects

  max_session_duration = var.max_session_duration

  tags = {
    Environment = "development"
    AccountId   = var.development_account_id
  }
}

# --------------------------------------------------------------------------
# Module: IAM for staging account
# --------------------------------------------------------------------------
# No admin role — staging is a pre-production mirror. Changes go through
# Terraform only. All team roles are read-only with heavy compute denied.

module "iam_staging" {
  source = "../../modules/iam-centralised"

  providers = {
    aws = aws.staging
  }

  role_prefix          = var.role_prefix
  trusted_account_arns = [var.gds_users_account_arn]

  admin_trusted_arns = var.admin_trusted_arns

  create_admin_role          = false
  create_readonly_role       = true
  create_security_audit_role = true
  create_terraform_role      = true

  terraform_cross_account_arns = ["arn:aws:iam::${var.production_account_id}:root"]

  team_roles = {
    data-scientist = { full_access = false, allow_heavy_compute = false }
    developer      = { full_access = false, allow_heavy_compute = false }
    analyst        = { full_access = false, allow_heavy_compute = false }
    explorer       = { full_access = false, allow_heavy_compute = false }
  }

  github_oidc_allowed_subjects = var.github_oidc_allowed_subjects

  max_session_duration = var.max_session_duration

  tags = {
    Environment = "staging"
    AccountId   = var.staging_account_id
  }
}

# --------------------------------------------------------------------------
# Module: IAM for Production account
# --------------------------------------------------------------------------
# Admin role enabled but restricted to named users only.
# All team roles are read-only with heavy compute denied.

module "iam_production" {
  source = "../../modules/iam-centralised"

  # No provider alias — uses the default (production) provider.

  role_prefix          = var.role_prefix
  trusted_account_arns = [var.gds_users_account_arn]

  admin_trusted_arns = var.admin_trusted_arns

  create_admin_role          = true
  create_readonly_role       = true
  create_security_audit_role = true
  create_terraform_role      = true

  team_roles = {
    data-scientist = { full_access = false, allow_heavy_compute = false }
    developer      = { full_access = false, allow_heavy_compute = false }
    analyst        = { full_access = false, allow_heavy_compute = false }
    explorer       = { full_access = false, allow_heavy_compute = false }
  }

  github_oidc_allowed_subjects = var.github_oidc_allowed_subjects

  max_session_duration = var.max_session_duration

  tags = {
    Environment = "production"
    AccountId   = var.production_account_id
  }
}

# ==========================================================================
# BUDGET ALERTS
# ==========================================================================

# --------------------------------------------------------------------------
# Budget: Development account
# --------------------------------------------------------------------------

module "budget_development" {
  source = "../../modules/budget-alerts"

  providers = {
    aws = aws.development
  }

  budget_prefix     = "${var.role_prefix}-development"
  monthly_limit_usd = var.budget_development_usd
  alert_emails      = var.budget_alert_emails

  tags = {
    Environment = "development"
    AccountId   = var.development_account_id
  }
}

# --------------------------------------------------------------------------
# Budget: Staging account
# --------------------------------------------------------------------------

module "budget_staging" {
  source = "../../modules/budget-alerts"

  providers = {
    aws = aws.staging
  }

  budget_prefix     = "${var.role_prefix}-staging"
  monthly_limit_usd = var.budget_staging_usd
  alert_emails      = var.budget_alert_emails

  tags = {
    Environment = "staging"
    AccountId   = var.staging_account_id
  }
}

# --------------------------------------------------------------------------
# Budget: Production account
# --------------------------------------------------------------------------

module "budget_production" {
  source = "../../modules/budget-alerts"

  # No provider alias — uses the default (Production) provider.

  budget_prefix     = "${var.role_prefix}-production"
  monthly_limit_usd = var.budget_production_usd
  alert_emails      = var.budget_alert_emails

  tags = {
    Environment = "production"
    AccountId   = var.production_account_id
  }
}
