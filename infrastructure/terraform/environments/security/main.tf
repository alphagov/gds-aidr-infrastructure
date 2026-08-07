# ============================================================
# Security Environment - Main
# ============================================================
# Manages cross-cutting platform security concerns: DNS,
# wildcard certificate reference, and DNS records for
# application subdomains across all workload environments
# (Development, Staging, Production).
#
# Naming convention: <environment>-<repository-name>.<domain_name>
# See root README for the full pattern.
#
# Existing manually-created AWS resources (hosted zone, ACM
# certificate) are referenced via data sources rather than
# managed here, to avoid destructive imports.
# ============================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100"
    }
  }

  backend "s3" {
    bucket       = "gds-aidr-terraform-state-production"
    key          = "security/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}

# ------------------------------------------------------------
# Providers
# ------------------------------------------------------------
# Security resources live in the Production account (DNS and
# certs are shared concerns above workload environments).
# ------------------------------------------------------------
provider "aws" {
  region = "eu-west-2"
  assume_role {
    role_arn = "arn:aws:iam::${var.production_account_id}:role/gds-aidr-terraform"
  }
  default_tags {
    tags = {
      Environment = "Production"
      ManagedBy   = "terraform"
      Repository  = "gds-aidr-infrastructure"
      Component   = "security"
    }
  }
}

# ACM certs for CloudFront must live in us-east-1. Data-only,
# no resources created in that region here.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  assume_role {
    role_arn = "arn:aws:iam::${var.production_account_id}:role/gds-aidr-terraform"
  }
}

# ------------------------------------------------------------
# Existing hosted zone and certificate
# ------------------------------------------------------------
# Both the hosted zone and wildcard certificate were created
# manually via the AWS Console (Route 53 Domains + Certificate
# Manager). They are referenced by ID/ARN via variables so
# this environment does not attempt to create or destroy them.
# ------------------------------------------------------------

data "aws_route53_zone" "main" {
  zone_id = var.hosted_zone_id
}

#data "aws_acm_certificate" "wildcard" {
#  provider = aws.us_east_1
#  arn      = var.certificate_arn
#}

# ------------------------------------------------------------
# Cross-account remote state - compute
# ------------------------------------------------------------
# The compute environment holds all three workload environments
# (Development, Staging, Production) in a single state file,
# managed via provider aliases. This block reads that state so
# DNS records can point at the correct CloudFront distribution
# per environment without hardcoding.
# ------------------------------------------------------------
data "terraform_remote_state" "compute" {
  backend = "s3"
  config = {
    bucket = "gds-aidr-terraform-state-production"
    key    = "compute/terraform.tfstate"
    region = "eu-west-2"
  }
}

# ------------------------------------------------------------
# Application subdomain records
# ------------------------------------------------------------
# One A record (CloudFront alias) per application per
# environment. The subdomain is composed from environment and
# repository name to enforce the naming convention:
#   <environment>-<repository-name>.<domain_name>
#
# Add a new app-environment by adding a map entry below.
# See README.md in this directory for the onboarding pattern.
# ------------------------------------------------------------
locals {
  app_environments = {
    "development-synthetic-email-generation" = {
      environment        = "dev"
      repo_name          = "synthetic-email-generation"
      cloudfront_domain  = data.terraform_remote_state.compute.outputs.development_cloudfront_domain_name
      cloudfront_zone_id = data.terraform_remote_state.compute.outputs.development_cloudfront_hosted_zone_id
    }

    # --- STAGING (deferred) ---
    # Uncomment when the Staging CloudFront distribution exists
    # in the compute environment.
    #
    # "staging-synthetic-email-generation" = {
    #   environment        = "staging"
    #   repo_name          = "synthetic-email-generation"
    #   cloudfront_domain  = data.terraform_remote_state.compute.outputs.staging_cloudfront_domain_name
    #   cloudfront_zone_id = data.terraform_remote_state.compute.outputs.staging_cloudfront_hosted_zone_id
    # }

    # --- PRODUCTION (deferred) ---
    # Uncomment when the Production CloudFront distribution
    # exists in the compute environment.
    #
    # "production-synthetic-email-generation" = {
    #   environment        = "prod"
    #   repo_name          = "synthetic-email-generation"
    #   cloudfront_domain  = data.terraform_remote_state.compute.outputs.production_cloudfront_domain_name
    #   cloudfront_zone_id = data.terraform_remote_state.compute.outputs.production_cloudfront_hosted_zone_id
    # }
  }
}

resource "aws_route53_record" "app_alias" {
  for_each = local.app_environments

  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${each.value.environment}-${each.value.repo_name}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = each.value.cloudfront_domain
    zone_id                = each.value.cloudfront_zone_id
    evaluate_target_health = false
  }
}
