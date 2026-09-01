# environments/compute/outputs.tf

# --------------------------------------------------------------------------
# Development account
# --------------------------------------------------------------------------

output "development_cluster_arn" {
  description = "ECS cluster ARN in the Development account."
  value       = module.ecs_cluster_development.cluster_arn
}

# --- moved to synthetic-email-generation repo infrastructure/ 
## ... in feat/decouple_compute work---
# output "development_service_name" {
#   description = "ECS service name for the API in the Development account."
#   value       = module.ecs_service_development.service_name
# }

# --- moved to synthetic-email-generation repo infrastructure/
## ... in feat/decouple_compute work---
# output "development_task_definition_arn" {
#   description = "Task definition ARN for the API in the Development account."
#   value       = module.ecs_service_development.task_definition_arn
# }

output "development_execution_role_arn" {
  description = "Execution role ARN for the API service in the Development account."
  value       = module.workload_iam_development.execution_role_arn
}

output "development_task_role_arn" {
  description = "Task role ARN for the API service in the Development account."
  value       = module.workload_iam_development.task_role_arn
}

output "development_ui_execution_role_arn" {
  description = "Execution role ARN for the UI service in the Development account."
  value       = module.workload_iam_ui_development.execution_role_arn
}

output "development_ui_task_role_arn" {
  description = "Task role ARN for the UI service in the Development account."
  value       = module.workload_iam_ui_development.task_role_arn
}

output "development_rds_endpoint" {
  description = "RDS PostgreSQL endpoint in the Development account."
  value       = module.rds_development.endpoint
}

output "development_rds_secret_arn" {
  description = "Secrets Manager ARN for the RDS credentials in the Development account."
  value       = module.rds_development.secret_arn
}

output "development_alb_dns_name" {
  description = "ALB DNS name in the Development account."
  value       = module.alb_development.alb_dns_name
}

output "development_alb_default_target_group_arn" {
  description = "Default ALB target group ARN (UI service) in the Development account."
  value       = module.alb_development.target_group_arn
}

output "development_alb_api_target_group_arn" {
  description = "API ALB target group ARN in the Development account."
  value       = module.alb_development.additional_target_group_arns["api"]
}

output "development_cloudfront_domain_name" {
  description = "CloudFront distribution domain name in the Development account."
  value       = module.cloudfront_waf_development.cloudfront_domain_name
}

output "development_cloudfront_hosted_zone_id" {
  description = "CloudFront hosted zone ID in the Development account."
  value       = module.cloudfront_waf_development.cloudfront_hosted_zone_id
}

# --------------------------------------------------------------------------
# Staging account
# --------------------------------------------------------------------------

output "staging_cluster_arn" {
  description = "ECS cluster ARN in the Staging account."
  value       = module.ecs_cluster_staging.cluster_arn
}

# --------------------------------------------------------------------------
# Production account
# --------------------------------------------------------------------------

output "production_cluster_arn" {
  description = "ECS cluster ARN in the Production account."
  value       = module.ecs_cluster_production.cluster_arn
}
