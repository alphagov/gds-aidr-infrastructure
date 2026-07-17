# iam-centralised/outputs.tf

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC identity provider created in this account."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "admin_role_arn" {
  description = "ARN of the admin role, if created."
  value       = var.create_admin_role ? aws_iam_role.admin[0].arn : null
}

output "readonly_role_arn" {
  description = "ARN of the readonly role, if created."
  value       = var.create_readonly_role ? aws_iam_role.readonly[0].arn : null
}

output "security_audit_role_arn" {
  description = "ARN of the security-audit role, if created."
  value       = var.create_security_audit_role ? aws_iam_role.security_audit[0].arn : null
}

output "terraform_role_arn" {
  description = "ARN of the terraform role, if created."
  value       = var.create_terraform_role ? aws_iam_role.terraform[0].arn : null
}

output "team_role_arns" {
  description = "Map of team role names to their ARNs."
  value       = { for k, v in aws_iam_role.team : k => v.arn }
}

output "ci_push_role_arn" {
  description = "ARN of the shared CI push role, if created."
  value       = var.create_ci_push_role ? aws_iam_role.ci_push[0].arn : null
}

output "ci_apply_role_arn" {
  description = "ARN of the shared CI apply role, if created."
  value       = var.create_ci_apply_role ? aws_iam_role.ci_apply[0].arn : null
}

# --------------------------------------------------------------------------
# Data reader role for synthetic data engine
# --------------------------------------------------------------------------

#´output "data_reader_role_arn" {
#  description = "ARN of the scoped data-reader role, if created. This is the ROLE_ARN given to internal and cross-government consumers."
#  value       = var.create_data_reader_role ? aws_iam_role.data_reader[0].arn : null
#}
