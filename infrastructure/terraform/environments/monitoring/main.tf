# environments/monitoring/main.tf
#
# Provisions the weekly CloudTrail digest pipeline across all three accounts.
# The SNS topic lives in Production (email subscription). One Lambda per
# account queries that account's CloudTrail and publishes to the shared topic.
#
# Runs from the Production account, assuming into Development and Staging via
# the gds-aidr-terraform role. Separate state from production-iam, networking,
# compute, and containers.

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
    key          = "monitoring/terraform.tfstate"
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
# Provider: Development
# --------------------------------------------------------------------------

provider "aws" {
  alias  = "development"
  region = "eu-west-2"

  assume_role {
    role_arn     = "arn:aws:iam::${var.development_account_id}:role/${var.role_prefix}-terraform"
    session_name = "monitoring-terraform"
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
# Provider: Staging
# --------------------------------------------------------------------------

provider "aws" {
  alias  = "staging"
  region = "eu-west-2"

  assume_role {
    role_arn     = "arn:aws:iam::${var.staging_account_id}:role/${var.role_prefix}-terraform"
    session_name = "monitoring-terraform"
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
# SNS topic — lives in Production, receives digests from all accounts
# --------------------------------------------------------------------------

resource "aws_sns_topic" "cloudtrail_digest" {
  name = "${var.role_prefix}-cloudtrail-weekly-digest"

  tags = {
    Environment = "production"
    AccountId   = var.production_account_id
  }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.cloudtrail_digest.arn
  protocol  = "email"
  endpoint  = var.digest_email
}

# Cross-account publish policy — allows Development and Staging Lambdas
# to publish to this topic in Production
resource "aws_sns_topic_policy" "cross_account" {
  arn = aws_sns_topic.cloudtrail_digest.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountPublish"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${var.development_account_id}:root",
            "arn:aws:iam::${var.staging_account_id}:root",
            "arn:aws:iam::${var.production_account_id}:root"
          ]
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.cloudtrail_digest.arn
      }
    ]
  })
}

# --------------------------------------------------------------------------
# CloudTrail digest: Development
# --------------------------------------------------------------------------

module "digest_development" {
  source = "../../modules/cloudtrail-digest"

  providers = {
    aws = aws.development
  }

  role_prefix   = var.role_prefix
  account_label = "Development"
  sns_topic_arn = aws_sns_topic.cloudtrail_digest.arn

  tags = {
    Environment = "development"
    AccountId   = var.development_account_id
  }
}

# --------------------------------------------------------------------------
# CloudTrail digest: Staging
# --------------------------------------------------------------------------

module "digest_staging" {
  source = "../../modules/cloudtrail-digest"

  providers = {
    aws = aws.staging
  }

  role_prefix   = var.role_prefix
  account_label = "Staging"
  sns_topic_arn = aws_sns_topic.cloudtrail_digest.arn

  tags = {
    Environment = "staging"
    AccountId   = var.staging_account_id
  }
}

# --------------------------------------------------------------------------
# CloudTrail digest: Production
# --------------------------------------------------------------------------

module "digest_production" {
  source = "../../modules/cloudtrail-digest"

  # No provider alias — uses the default (Production) provider.

  role_prefix   = var.role_prefix
  account_label = "Production"
  sns_topic_arn = aws_sns_topic.cloudtrail_digest.arn

  tags = {
    Environment = "production"
    AccountId   = var.production_account_id
  }
}
