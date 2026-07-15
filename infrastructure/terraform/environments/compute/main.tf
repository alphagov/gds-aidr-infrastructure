
# environments/compute/main.tf
#
# Provisions workload IAM roles and an ECS cluster in each of the three
# accounts, plus the synthetic-email-generation Fargate service in
# Development, now attached to an ALB. Staging and Production get clusters
# and workload IAM only, ready for future services.

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
    key          = "compute/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}

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

provider "aws" {
  alias  = "development"
  region = "eu-west-2"

  assume_role {
    role_arn     = "arn:aws:iam::${var.development_account_id}:role/${var.role_prefix}-terraform"
    session_name = "compute-terraform"
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

provider "aws" {
  alias  = "staging"
  region = "eu-west-2"

  assume_role {
    role_arn     = "arn:aws:iam::${var.staging_account_id}:role/${var.role_prefix}-terraform"
    session_name = "compute-terraform"
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

data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "gds-aidr-terraform-state-production"
    key    = "networking/terraform.tfstate"
    region = "eu-west-2"
  }
}

data "terraform_remote_state" "containers" {
  backend = "s3"
  config = {
    bucket = "gds-aidr-terraform-state-production"
    key    = "containers/terraform.tfstate"
    region = "eu-west-2"
  }
}

# --------------------------------------------------------------------------
# Development: workload IAM, ECS cluster, ALB, and the generation service
# --------------------------------------------------------------------------

module "workload_iam_development" {
  source = "../../modules/workload-iam"

  providers = {
    aws = aws.development
  }

  role_prefix   = var.role_prefix
  workload_name = "synthetic-email-generation"

  tags = {
    Environment = "development"
    AccountId   = var.development_account_id
  }
}

module "ecs_cluster_development" {
  source = "../../modules/ecs-cluster"

  providers = {
    aws = aws.development
  }

  environment_name = "Development"
  cluster_name     = "${var.role_prefix}-cluster"

  tags = {
    Environment = "development"
    AccountId   = var.development_account_id
  }
}

module "alb_development" {
  source = "../../modules/alb"

  providers = {
    aws = aws.development
  }

  environment_name  = "Development"
  alb_name          = "${var.role_prefix}-alb"
  vpc_id            = data.terraform_remote_state.networking.outputs.development_vpc_id
  public_subnet_ids = data.terraform_remote_state.networking.outputs.development_public_subnet_ids
  security_group_id = data.terraform_remote_state.networking.outputs.development_alb_security_group_id

  port_80_enabled     = true
  target_port         = var.synthetic_email_generation_container_port
  health_check_path   = var.synthetic_email_generation_health_check_path
  acm_certificate_arn = null

  tags = {
    Environment = "development"
    AccountId   = var.development_account_id
  }
}

module "ecs_service_development" {
  source = "../../modules/ecs-fargate-service"

  providers = {
    aws = aws.development
  }

  environment_name = "Development"
  service_name     = "synthetic-email-generation"
  cluster_arn      = module.ecs_cluster_development.cluster_arn

  execution_role_arn = module.workload_iam_development.execution_role_arn
  task_role_arn      = module.workload_iam_development.task_role_arn

  container_image = "${data.terraform_remote_state.containers.outputs.development_repository_urls["synthetic-email-generation"]}:latest"
  container_port  = var.synthetic_email_generation_container_port

  cpu    = 256
  memory = 512

  subnet_ids         = data.terraform_remote_state.networking.outputs.development_private_app_subnet_ids
  security_group_ids = [data.terraform_remote_state.networking.outputs.development_ecs_task_security_group_id]
  assign_public_ip   = false

  create_service   = true
  desired_count    = 1
  target_group_arn = module.alb_development.target_group_arn

  tags = {
    Environment = "development"
    AccountId   = var.development_account_id
  }
}

# --------------------------------------------------------------------------
# Staging: workload IAM and ECS cluster only, ready for future services
# --------------------------------------------------------------------------

module "workload_iam_staging" {
  source = "../../modules/workload-iam"

  providers = {
    aws = aws.staging
  }

  role_prefix   = var.role_prefix
  workload_name = "synthetic-email-generation"

  tags = {
    Environment = "staging"
    AccountId   = var.staging_account_id
  }
}

module "ecs_cluster_staging" {
  source = "../../modules/ecs-cluster"

  providers = {
    aws = aws.staging
  }

  environment_name = "Staging"
  cluster_name     = "${var.role_prefix}-cluster"

  tags = {
    Environment = "staging"
    AccountId   = var.staging_account_id
  }
}

# --------------------------------------------------------------------------
# Production: workload IAM and ECS cluster only, ready for future services
# --------------------------------------------------------------------------

module "workload_iam_production" {
  source = "../../modules/workload-iam"

  role_prefix   = var.role_prefix
  workload_name = "synthetic-email-generation"

  tags = {
    Environment = "production"
    AccountId   = var.production_account_id
  }
}

module "ecs_cluster_production" {
  source = "../../modules/ecs-cluster"

  environment_name = "Production"
  cluster_name     = "${var.role_prefix}-cluster"

  tags = {
    Environment = "production"
    AccountId   = var.production_account_id
  }
}
