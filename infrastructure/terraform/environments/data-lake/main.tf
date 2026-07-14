# environments/data-lake/main.tf
#
# Stands up the synthetic data lake in the Production account. Runs separately
# from production-iam so storage and IAM have independent state and blast
# radius.

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
    key          = "data-lake/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}

# --------------------------------------------------------------------------
# Provider: Production
# --------------------------------------------------------------------------
# The lake lives in the Production account.

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
# Module: data lake
# --------------------------------------------------------------------------

module "data_lake" {
  source = "../../modules/data-lake"

  bucket_name           = var.bucket_name
  production_account_id = var.production_account_id
  dataset_prefix        = var.dataset_prefix
  metadata_prefix       = var.metadata_prefix
  role_prefix           = var.role_prefix

  reader_account_arns = var.reader_account_arns

  create_lakeformation_register_role = var.create_lakeformation_register_role
  lakeformation_register_role_arn    = var.lakeformation_register_role_arn

  audit_log_retention_days = var.audit_log_retention_days

  tags = {
    Environment = "production"
    AccountId   = var.production_account_id
  }
}
