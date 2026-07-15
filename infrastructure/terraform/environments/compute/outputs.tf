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

output "staging_cluster_arn" {
  value = module.ecs_cluster_staging.cluster_arn
}

output "production_cluster_arn" {
  value = module.ecs_cluster_production.cluster_arn
}

output "development_alb_dns_name" {
  description = "URL to reach the Development service over HTTP, no domain needed."
  value       = module.alb_development.alb_dns_name
}
