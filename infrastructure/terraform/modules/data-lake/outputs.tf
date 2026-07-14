# data-lake/outputs.tf

output "bucket_name" {
  description = "Name of the data lake bucket. Consumed by the data backend repository."
  value       = aws_s3_bucket.data_lake.bucket
}

output "bucket_arn" {
  description = "ARN of the data lake bucket. Consumed by the data backend repository and the data-reader role."
  value       = aws_s3_bucket.data_lake.arn
}

output "kms_key_arn" {
  description = "ARN of the data lake encryption key. Readers and writers need decrypt and encrypt on this key."
  value       = aws_kms_key.data_lake.arn
}

output "dataset_prefix" {
  description = "Prefix for dataset files."
  value       = var.dataset_prefix
}

output "metadata_prefix" {
  description = "Prefix for metadata files."
  value       = var.metadata_prefix
}

output "audit_log_group" {
  description = "Name of the object-level audit log group."
  value       = aws_cloudwatch_log_group.data_lake_audit.name
}

output "lakeformation_register_role_arn" {
  description = "ARN of the Lake Formation registration role, whether self-created or supplied externally."
  value       = local.lakeformation_register_role_arn
}
