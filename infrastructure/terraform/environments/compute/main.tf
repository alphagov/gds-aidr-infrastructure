# environments/compute/main.tf
#
# Provisions workload IAM roles and an ECS cluster in each of the three
# accounts, plus the synthetic-email-generation Fargate service in
# Development only — serving already happens via Lambda, not ECS, so
# Staging and Production get clusters ready for future services without
# this specific workload attached.
#
# Reads subnet, security group, and ECR repository details from the
# networking and containers state files via remote state, rather than
# duplicating those values in tfvars.

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

# --------------------------------------------------------------------------
# Provider: staging
# --------------------------------------------------------------------------

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

# --------------------------------------------------------------------------
# Remote state: networking
# --------------------------------------------------------------------------
# Single data source — networking's state already contains outputs for all
# three accounts. Read via the production S3 bucket, which the current
# session already has access to.

data "terraform_remote_state" "networking" {
  backend = "s3"

  config = {
    bucket = "gds-aidr-terraform-state-production"
    key    = "networking/terraform.tfstate"
    region = "eu-west-2"
  }
}

# --------------------------------------------------------------------------
# Remote state: containers
# --------------------------------------------------------------------------

data "terraform_remote_state" "containers" {
  backend = "s3"

  config = {
    bucket = "gds-aidr-terraform-state-production"
    key    = "containers/terraform.tfstate"
    region = "eu-west-2"
  }
}

# --------------------------------------------------------------------------
# Development: workload IAM, ECS cluster, and the generation service
# --------------------------------------------------------------------------

module "workload_iam_development" {
  source = "../../modules/workload-iam"

  providers = {
    aws = aws.development
  }

  role_prefix   = var.role_prefix
  workload_name = "synthetic-email-generation"

  execution_role_secrets_arns = [module.rds_development.secret_arn]

  task_role_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowBedrockInvoke"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "*"
      }
    ]
  })

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
module "rds_development" {
  source = "../../modules/rds-postgres"

  providers = {
    aws = aws.development
  }

  environment_name = "Development"
  identifier       = "email-generation"
  db_name          = "email_generation"

  vpc_id            = data.terraform_remote_state.networking.outputs.development_vpc_id
  subnet_ids        = data.terraform_remote_state.networking.outputs.development_private_data_subnet_ids
  security_group_id = data.terraform_remote_state.networking.outputs.development_private_data_security_group_id

  multi_az            = false
  deletion_protection = false
  skip_final_snapshot = true

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

  environment_variables = [
    { name = "LLM_PROVIDER", value = "bedrock" },
    { name = "LLM_MODEL_OVERRIDE", value = var.bedrock_model_id },
    { name = "AWS_REGION", value = "eu-west-2" },
    { name = "INTERNAL_ACCESS_TOKEN", value = var.team_token }
  ]

  # container_image = "${data.terraform_remote_state.containers.outputs.development_repository_urls["synthetic-email-generation"]}:latest"
  container_image = "${data.terraform_remote_state.containers.outputs.development_repository_urls["synthetic-email-generation"]}:${var.development_api_image_tag}"
  container_port  = 3000

  secrets = [
    { name = "DATABASE_URL", value_from = "${module.rds_development.secret_arn}:url::" }
  ]

  cpu    = 512
  memory = 1024

  subnet_ids         = data.terraform_remote_state.networking.outputs.development_private_app_subnet_ids
  security_group_ids = [data.terraform_remote_state.networking.outputs.development_ecs_task_security_group_id]
  assign_public_ip   = false

  create_service   = true
  desired_count    = 1
  target_group_arn = module.alb_development.additional_target_group_arns["api"]

  tags = {
    Environment = "development"
    AccountId   = var.development_account_id
  }
}

# --------------------------------------------------------------------------
# Development: UI workload IAM, ALB, CloudFront/WAF, UI service
# --------------------------------------------------------------------------
# UI shares the existing synthetic-email-generation ECR repo, distinguished
# by tag prefix (ui-...) rather than a separate repository. Revisit if/when
# separate lifecycle policies or access scoping are needed per app.

module "workload_iam_ui_development" {
  source = "../../modules/workload-iam"

  providers = {
    aws = aws.development
  }

  role_prefix   = var.role_prefix
  workload_name = "synthetic-email-generation-ui"

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
  acm_certificate_arn = null

  target_port       = 8080
  health_check_path = "/health"

  additional_routes = [
    {
      name              = "api"
      port              = 3000
      health_check_path = "/health"
      path_patterns     = ["/organisations*", "/characters*", "/threads*", "/character*"]
      priority          = 100
    }
  ]

  tags = {
    Environment = "development"
    AccountId   = var.development_account_id
  }
}

resource "aws_security_group_rule" "alb_to_ecs_tasks" {
  provider = aws.development

  type                     = "ingress"
  from_port                = 3000
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = data.terraform_remote_state.networking.outputs.development_alb_security_group_id
  security_group_id        = data.terraform_remote_state.networking.outputs.development_ecs_task_security_group_id
  description              = "Allow ALB to reach both UI (8080) and API (3000) tasks"
}

provider "aws" {
  alias  = "development_us_east_1"
  region = "us-east-1"

  assume_role {
    role_arn     = "arn:aws:iam::${var.development_account_id}:role/${var.role_prefix}-terraform"
    session_name = "compute-terraform-us-east-1"
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

module "cloudfront_waf_development" {
  source = "../../modules/cloudfront-waf"

  providers = {
    aws           = aws.development
    aws.us_east_1 = aws.development_us_east_1
  }

  environment_name      = "Development"
  distribution_name     = "synthetic-email-generation"
  alb_dns_name          = module.alb_development.alb_dns_name
  alb_arn               = module.alb_development.alb_arn
  alb_security_group_id = data.terraform_remote_state.networking.outputs.development_alb_security_group_id
  team_token            = var.team_token

  allowed_countries = ["GB"]

  tags = {
    Environment = "development"
    AccountId   = var.development_account_id
  }
}

module "ecs_service_ui_development" {
  source = "../../modules/ecs-fargate-service"

  providers = {
    aws = aws.development
  }

  environment_name = "Development"
  service_name     = "synthetic-email-generation-ui"
  cluster_arn      = module.ecs_cluster_development.cluster_arn

  execution_role_arn = module.workload_iam_ui_development.execution_role_arn
  task_role_arn      = module.workload_iam_ui_development.task_role_arn

  container_image = "${data.terraform_remote_state.containers.outputs.development_repository_urls["synthetic-email-generation"]}:${var.development_ui_image_tag}"
  container_port  = 8080

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

  # No provider alias — uses the default (production) provider.

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
