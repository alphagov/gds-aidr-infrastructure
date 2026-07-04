# s3-bucket/outputs.tf

output "bucket_id" {
  description = "ID of the bucket."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the bucket, used in IAM and bucket policies."
  value       = aws_s3_bucket.this.arn
}

output "bucket_name" {
  description = "Name of the bucket."
  value       = aws_s3_bucket.this.bucket
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the bucket."
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}
