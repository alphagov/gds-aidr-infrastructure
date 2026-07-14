# environments/data-lake/outputs.tf
#
# These outputs feed the other configurations. After applying this
# environment, copy the values into:
#   - production-iam/terraform.tfvars (data_lake_bucket_arn, data_lake_kms_key_arn)
#   - the data backend repository's data-pipeline and api tfvars

output "bucket_name" {
  description = "Name of the data lake bucket. Give this to the data backend repository."
  value       = module.data_lake.bucket_name
}

output "bucket_arn" {
  description = "ARN of the data lake bucket. Give this to the data backend repository and the data-reader role."
  value       = module.data_lake.bucket_arn
}

output "kms_key_arn" {
  description = "ARN of the data lake encryption key."
  value       = module.data_lake.kms_key_arn
}

output "dataset_prefix" {
  description = "Prefix for dataset files."
  value       = module.data_lake.dataset_prefix
}

output "metadata_prefix" {
  description = "Prefix for metadata files."
  value       = module.data_lake.metadata_prefix
}

output "audit_log_group" {
  description = "Name of the object-level audit log group."
  value       = module.data_lake.audit_log_group
}

output "lakeformation_register_role_arn" {
  description = "ARN of the Lake Formation registration role, whether self-created or supplied externally."
  value       = module.data_lake.lakeformation_register_role_arn
}
