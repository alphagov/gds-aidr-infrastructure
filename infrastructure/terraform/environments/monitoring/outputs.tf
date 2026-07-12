# environments/monitoring/outputs.tf

output "sns_topic_arn" {
  description = "ARN of the CloudTrail digest SNS topic."
  value       = aws_sns_topic.cloudtrail_digest.arn
}

output "development_lambda_arn" {
  description = "ARN of the digest Lambda in the Development account."
  value       = module.digest_development.lambda_function_arn
}

output "staging_lambda_arn" {
  description = "ARN of the digest Lambda in the Staging account."
  value       = module.digest_staging.lambda_function_arn
}

output "production_lambda_arn" {
  description = "ARN of the digest Lambda in the Production account."
  value       = module.digest_production.lambda_function_arn
}
