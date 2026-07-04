# environments/containers/main.tf
#
# Provisions ECR repositories in each of the three accounts. Runs from the
# production account, assuming into development and staging via the
# gds-aidr-terraform role. Separate state from networking and production-iam
# — container repository changes have a different lifecycle from both.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "gds-aidr-terraform-state-production"
    key          = "containers/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}

# --------------------------------------------------------------------------
# Provider: production (default — no alias needed)
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
# Provider: development
# --------------------------------------------------------------------------

provider "aws" {
  alias  = "development"
  region = "eu-west-2"

  assume_role {
    role_arn     = "arn:aws:iam::${var.development_account_id}:role/${var.role_prefix}-terraform"
    session_name = "containers-terraform"
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
# Provider: staging
# --------------------------------------------------------------------------

provider "aws" {
  alias  = "staging"
  region = "eu-west-2"

  assume_role {
    role_arn     = "arn:aws:iam::${var.staging_account_id}:role/${var.role_prefix}-terraform"
    session_name = "containers-terraform"
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
# ECR repositories: development
# --------------------------------------------------------------------------

module "ecr_development" {
  source   = "../../modules/ecr"
  for_each = toset(var.repository_names)

  providers = {
    aws = aws.development
  }

  environment_name = "Development"
  repository_name  = each.value

  tags = {
    Environment = "development"
    AccountId   = var.development_account_id
  }
}

# --------------------------------------------------------------------------
# ECR repositories: staging
# --------------------------------------------------------------------------

module "ecr_staging" {
  source   = "../../modules/ecr"
  for_each = toset(var.repository_names)

  providers = {
    aws = aws.staging
  }

  environment_name = "Staging"
  repository_name  = each.value

  tags = {
    Environment = "staging"
    AccountId   = var.staging_account_id
  }
}

# --------------------------------------------------------------------------
# ECR repositories: production
# --------------------------------------------------------------------------

module "ecr_production" {
  source   = "../../modules/ecr"
  for_each = toset(var.repository_names)

  # No provider alias — uses the default (production) provider.

  environment_name = "Production"
  repository_name  = each.value

  tags = {
    Environment = "production"
    AccountId   = var.production_account_id
  }
}
