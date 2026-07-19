# environments/compute/outputs.tf

output "development_cluster_arn" {
  value = module.ecs_cluster_development.cluster_arn
}

output "development_service_name" {
  value = module.ecs_service_development.service_name
}

output "development_task_definition_arn" {
  value = module.ecs_service_development.task_definition_arn
}

output "development_execution_role_arn" {
  value = module.workload_iam_development.execution_role_arn
}

output "development_task_role_arn" {
  value = module.workload_iam_development.task_role_arn
}

output "development_rds_endpoint" {
  value = module.rds_development.endpoint
}

output "development_rds_secret_arn" {
  value = module.rds_development.secret_arn
}

output "development_alb_dns_name" {
  value = module.alb_development.alb_dns_name
}

output "development_cloudfront_domain_name" {
  value = module.cloudfront_waf_development.cloudfront_domain_name
}

output "staging_cluster_arn" {
  value = module.ecs_cluster_staging.cluster_arn
}

output "production_cluster_arn" {
  value = module.ecs_cluster_production.cluster_arn
}

