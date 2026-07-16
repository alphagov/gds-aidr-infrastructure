# rds-postgres/outputs.tf

output "endpoint" {
  description = "Connection endpoint (host:port)."
  value       = aws_db_instance.this.endpoint
}

output "address" {
  description = "Host only, no port."
  value       = aws_db_instance.this.address
}

output "port" {
  value = aws_db_instance.this.port
}

output "db_name" {
  value = aws_db_instance.this.db_name
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret holding full connection details. Grant this to the execution role via workload-iam's execution_role_secrets_arns."
  value       = aws_secretsmanager_secret.this.arn
}
