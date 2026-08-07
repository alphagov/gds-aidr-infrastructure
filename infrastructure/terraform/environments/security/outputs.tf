# ============================================================
# Security Environment - Outputs
# ============================================================
# Exposed for consumption by other environments (compute,
# monitoring, etc.) via terraform_remote_state.
# ============================================================

output "domain_name" {
  description = "Root platform domain."
  value       = var.domain_name
}

output "hosted_zone_id" {
  description = "Route 53 hosted zone ID for the platform domain."
  value       = data.aws_route53_zone.main.zone_id
}

output "hosted_zone_name_servers" {
  description = "Name servers for the platform hosted zone. Useful for DNS delegation checks."
  value       = data.aws_route53_zone.main.name_servers
}

output "wildcard_certificate_arn" {
  description = "ARN of the wildcard ACM certificate covering the platform domain."
  value       = data.aws_acm_certificate.wildcard.arn
}

output "app_subdomains" {
  description = "Map of application subdomains registered under the platform domain."
  value = {
    for name, config in local.app_environments :
    name => "${config.environment}-${config.repo_name}.${var.domain_name}"
  }
}
