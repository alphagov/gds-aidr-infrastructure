# environments/networking/outputs.tf

# --------------------------------------------------------------------------
# Development
# --------------------------------------------------------------------------

output "development_vpc_id" {
  value = module.vpc_development.vpc_id
}

output "development_private_app_subnet_ids" {
  value = module.vpc_development.private_app_subnet_ids
}

output "development_private_data_subnet_ids" {
  value = module.vpc_development.private_data_subnet_ids
}

output "development_ecs_task_security_group_id" {
  value = module.vpc_development.ecs_task_security_group_id
}

output "development_alb_security_group_id" {
  value = module.vpc_development.alb_security_group_id
}

output "development_private_data_security_group_id" {
  value = module.vpc_development.private_data_security_group_id
}

# --------------------------------------------------------------------------
# Staging
# --------------------------------------------------------------------------

output "staging_vpc_id" {
  value = module.vpc_staging.vpc_id
}

output "staging_private_app_subnet_ids" {
  value = module.vpc_staging.private_app_subnet_ids
}

output "staging_private_data_subnet_ids" {
  value = module.vpc_staging.private_data_subnet_ids
}

output "staging_ecs_task_security_group_id" {
  value = module.vpc_staging.ecs_task_security_group_id
}

output "staging_alb_security_group_id" {
  value = module.vpc_staging.alb_security_group_id
}

output "staging_private_data_security_group_id" {
  value = module.vpc_staging.private_data_security_group_id
}
# --------------------------------------------------------------------------
# Production
# --------------------------------------------------------------------------

output "production_vpc_id" {
  value = module.vpc_production.vpc_id
}

output "production_private_app_subnet_ids" {
  value = module.vpc_production.private_app_subnet_ids
}

output "production_private_data_subnet_ids" {
  value = module.vpc_production.private_data_subnet_ids
}

output "production_ecs_task_security_group_id" {
  value = module.vpc_production.ecs_task_security_group_id
}

output "production_alb_security_group_id" {
  value = module.vpc_production.alb_security_group_id
}

output "production_private_data_security_group_id" {
  value = module.vpc_production.private_data_security_group_id
}

output "production_s3_vpc_endpoint_id" {
  description = "Used later for the datalake bucket policy network-path restriction."
  value       = module.vpc_production.s3_vpc_endpoint_id
}
