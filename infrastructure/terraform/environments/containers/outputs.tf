# environments/containers/outputs.tf

output "development_repository_urls" {
  description = "Repository URLs in the development account, keyed by repository name."
  value       = { for name, mod in module.ecr_development : name => mod.repository_url }
}

output "staging_repository_urls" {
  description = "Repository URLs in the staging account, keyed by repository name."
  value       = { for name, mod in module.ecr_staging : name => mod.repository_url }
}

output "production_repository_urls" {
  description = "Repository URLs in the production account, keyed by repository name."
  value       = { for name, mod in module.ecr_production : name => mod.repository_url }
}
