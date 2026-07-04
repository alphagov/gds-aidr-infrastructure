# environments/networking/main.tf
#
# Provisions a VPC in each of the three accounts (development, staging,
# production). Runs from the production account, assuming into development
# and staging via the existing gds-aidr-terraform role created by
# production-iam. Separate state from production-iam — networking changes
# more frequently than IAM and should not share blast radius with it.

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
    key          = "networking/terraform.tfstate"
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
    session_name = "networking-terraform"
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
    session_name = "networking-terraform"
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
# Module: VPC for development account
# --------------------------------------------------------------------------
# Single NAT gateway — cost-conscious, this is the sandbox account.

module "vpc_development" {
  source = "../../modules/vpc"

  providers = {
    aws = aws.development
  }

  environment_name           = "Development"
  vpc_cidr                   = var.development_vpc_cidr
  azs                        = var.azs
  public_subnet_cidrs        = var.development_public_subnet_cidrs
  private_app_subnet_cidrs   = var.development_private_app_subnet_cidrs
  private_data_subnet_cidrs  = var.development_private_data_subnet_cidrs
  nat_gateway_count          = 1
  create_interface_endpoints = true

  tags = {
    Environment = "development"
    AccountId   = var.development_account_id
  }
}

# --------------------------------------------------------------------------
# Module: VPC for staging account
# --------------------------------------------------------------------------
# Three NAT gateways for high availability, matching production.

module "vpc_staging" {
  source = "../../modules/vpc"

  providers = {
    aws = aws.staging
  }

  environment_name           = "Staging"
  vpc_cidr                   = var.staging_vpc_cidr
  azs                        = var.azs
  public_subnet_cidrs        = var.staging_public_subnet_cidrs
  private_app_subnet_cidrs   = var.staging_private_app_subnet_cidrs
  private_data_subnet_cidrs  = var.staging_private_data_subnet_cidrs
  nat_gateway_count          = 3
  create_interface_endpoints = true

  tags = {
    Environment = "staging"
    AccountId   = var.staging_account_id
  }
}

# --------------------------------------------------------------------------
# Module: VPC for production account
# --------------------------------------------------------------------------
# Three NAT gateways for high availability.

module "vpc_production" {
  source = "../../modules/vpc"

  # No provider alias — uses the default (production) provider.

  environment_name           = "Production"
  vpc_cidr                   = var.production_vpc_cidr
  azs                        = var.azs
  public_subnet_cidrs        = var.production_public_subnet_cidrs
  private_app_subnet_cidrs   = var.production_private_app_subnet_cidrs
  private_data_subnet_cidrs  = var.production_private_data_subnet_cidrs
  nat_gateway_count          = 3
  create_interface_endpoints = true

  tags = {
    Environment = "production"
    AccountId   = var.production_account_id
  }
}
