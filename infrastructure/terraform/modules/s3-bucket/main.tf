# s3-bucket/main.tf
#
# Creates a single S3 bucket with KMS encryption, versioning, a public
# access block, and an optional lifecycle policy. Called once per bucket
# from any environment. Public access block is not configurable — always
# enabled regardless of caller.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name

  tags = merge(var.tags, {
    Name = "${var.environment_name}-${var.bucket_name}"
  })
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count = var.noncurrent_version_expiration_days != null || var.abort_incomplete_multipart_upload_days != null ? 1 : 0

  bucket = aws_s3_bucket.this.id

  rule {
    id     = "baseline"
    status = "Enabled"

    dynamic "noncurrent_version_expiration" {
      for_each = var.noncurrent_version_expiration_days != null ? [1] : []
      content {
        noncurrent_days = var.noncurrent_version_expiration_days
      }
    }

    dynamic "abort_incomplete_multipart_upload" {
      for_each = var.abort_incomplete_multipart_upload_days != null ? [1] : []
      content {
        days_after_initiation = var.abort_incomplete_multipart_upload_days
      }
    }
  }
}

resource "aws_s3_object" "prefixes" {
  for_each = toset(var.prefixes)

  bucket  = aws_s3_bucket.this.id
  key     = "${each.value}/"
  content = ""
}

resource "aws_s3_bucket_policy" "this" {
  count = var.bucket_policy_json != null ? 1 : 0

  bucket = aws_s3_bucket.this.id
  policy = var.bucket_policy_json
}
