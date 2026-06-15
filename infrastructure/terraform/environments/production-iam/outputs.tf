# environments/production-iam/outputs.tf
#
# --------------------------------------------------------------------------
# Development account
# --------------------------------------------------------------------------

output "development_oidc_provider_arn" {
  description = "GitHub OIDC provider ARN in the Development account."
  value       = module.iam_development.oidc_provider_arn
}

output "development_admin_role_arn" {
  description = "Admin role ARN in the Development account."
  value       = module.iam_development.admin_role_arn
}

output "development_readonly_role_arn" {
  description = "Readonly role ARN in the Development account."
  value       = module.iam_development.readonly_role_arn
}

output "development_terraform_role_arn" {
  description = "Terraform role ARN in the Development account."
  value       = module.iam_development.terraform_role_arn
}

output "development_team_role_arns" {
  description = "Map of team role names to ARNs in the Development account."
  value       = module.iam_development.team_role_arns
}

# --------------------------------------------------------------------------
# Staging account
# --------------------------------------------------------------------------

output "staging_oidc_provider_arn" {
  description = "GitHub OIDC provider ARN in the Staging account."
  value       = module.iam_staging.oidc_provider_arn
}

output "staging_readonly_role_arn" {
  description = "Readonly role ARN in the Staging account."
  value       = module.iam_staging.readonly_role_arn
}

output "staging_terraform_role_arn" {
  description = "Terraform role ARN in the Staging account."
  value       = module.iam_staging.terraform_role_arn
}

output "staging_team_role_arns" {
  description = "Map of team role names to ARNs in the Staging account."
  value       = module.iam_staging.team_role_arns
}

# --------------------------------------------------------------------------
# Production account
# --------------------------------------------------------------------------

output "production_oidc_provider_arn" {
  description = "GitHub OIDC provider ARN in the Production account."
  value       = module.iam_production.oidc_provider_arn
}

output "production_admin_role_arn" {
  description = "Admin role ARN in the Production account."
  value       = module.iam_production.admin_role_arn
}

output "production_readonly_role_arn" {
  description = "Readonly role ARN in the Production account."
  value       = module.iam_production.readonly_role_arn
}

output "production_terraform_role_arn" {
  description = "Terraform role ARN in the Production account."
  value       = module.iam_production.terraform_role_arn
}

output "production_team_role_arns" {
  description = "Map of team role names to ARNs in the Production account."
  value       = module.iam_production.team_role_arns
}

# --------------------------------------------------------------------------
# Budget outputs
# --------------------------------------------------------------------------

output "development_budget_id" {
  description = "Budget ID for the Development account."
  value       = module.budget_development.budget_id
}

output "staging_budget_id" {
  description = "Budget ID for the Staging account."
  value       = module.budget_staging.budget_id
}

output "production_budget_id" {
  description = "Budget ID for the Production account."
  value       = module.budget_production.budget_id
}
