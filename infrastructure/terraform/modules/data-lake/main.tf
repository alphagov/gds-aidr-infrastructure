# data-lake/main.tf
#
# The synthetic data lake. One bucket holds the datasets and their metadata
# under separate prefixes. Lake Formation governs access to the metadata so it
# can be granted separately from the datasets.
#
# This is the storage the data backend writes to and consumers read from. The
# roles that write and read are defined elsewhere: the generation task role in
# the data backend repository, and the data-reader role in the iam-centralised
# module. This module owns the bucket and the governance, not the principals.
#
# The lake lives in the Production account. Datasets are read cross-account
# from Development and Staging rather than copied, so there is one
# authoritative copy.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# --------------------------------------------------------------------------
# Bucket
# --------------------------------------------------------------------------

resource "aws_s3_bucket" "data_lake" {
  bucket = var.bucket_name

  tags = var.tags
}

# Block all public access. The lake is never public. External access is
# brokered through the API, not through bucket exposure.

resource "aws_s3_bucket_public_access_block" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Encrypt at rest with a customer managed key so key access can be controlled
# and audited separately from the bucket.

resource "aws_kms_key" "data_lake" {
  description             = "Encryption key for the synthetic data lake."
  enable_key_rotation     = true
  deletion_window_in_days = 30

  # Cross-account reads need the key policy to allow the reader accounts, not
  # only their IAM policies. The account root keeps administrative control of
  # the key; the reader accounts get decrypt only.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid    = "AllowAccountAdministration"
          Effect = "Allow"
          Principal = {
            AWS = "arn:aws:iam::${var.production_account_id}:root"
          }
          Action   = "kms:*"
          Resource = "*"
        }
      ],
      length(var.reader_account_arns) > 0 ? [
        {
          Sid    = "AllowCrossAccountDecrypt"
          Effect = "Allow"
          Principal = {
            AWS = var.reader_account_arns
          }
          Action = [
            "kms:Decrypt",
            "kms:DescribeKey"
          ]
          Resource = "*"
        }
      ] : []
    )
  })

  tags = var.tags
}

resource "aws_kms_alias" "data_lake" {
  name          = "alias/${var.bucket_name}"
  target_key_id = aws_kms_key.data_lake.key_id
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.data_lake.arn
    }
    bucket_key_enabled = true
  }
}

# Keep version history so an overwrite or delete can be recovered.

resource "aws_s3_bucket_versioning" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  versioning_configuration {
    status = "Enabled"
  }
}

# --------------------------------------------------------------------------
# Bucket policy: allow cross-account read from Development and Staging
# --------------------------------------------------------------------------
# The data-reader role is assumed from the gds-users root, but the assumed
# session acts against this bucket from whichever account the consumer started
# in. This policy permits read from the trusted account roots on the dataset
# and metadata prefixes. Writes are not granted here; only the generation task
# role writes, through its own identity policy.

resource "aws_s3_bucket_policy" "data_lake" {
  count = length(var.reader_account_arns) > 0 ? 1 : 0

  bucket = aws_s3_bucket.data_lake.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountRead"
        Effect = "Allow"
        Principal = {
          AWS = var.reader_account_arns
        }
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.data_lake.arn,
          "${aws_s3_bucket.data_lake.arn}/${var.dataset_prefix}*",
          "${aws_s3_bucket.data_lake.arn}/${var.metadata_prefix}*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "true"
          }
        }
      }
    ]
  })
}

# --------------------------------------------------------------------------
# CloudTrail data events on the bucket
# --------------------------------------------------------------------------
# Every read and write of an object in the lake is logged, so access to a
# shared dataset is auditable. This is a condition of sharing, not an optional
# extra. The log group is created here; wiring a trail to it is done in the
# environment once the audit strategy is confirmed.

resource "aws_cloudwatch_log_group" "data_lake_audit" {
  name              = "/datalake/${var.bucket_name}/audit"
  retention_in_days = var.audit_log_retention_days

  tags = var.tags
}

# --------------------------------------------------------------------------
# Lake Formation
# --------------------------------------------------------------------------
# Registers the metadata prefix with Lake Formation so reads of the metadata
# can be governed and granted separately from the datasets. The datasets prefix
# is governed by the bucket policy and the reader role; the metadata prefix is
# governed here so discovery can be granted without granting consumption.

# --------------------------------------------------------------------------
# Lake Formation registration role
# --------------------------------------------------------------------------
# Lake Formation assumes this role to read and write the registered metadata
# location on the caller's behalf. Scoped to the data lake bucket's metadata
# prefix and the data lake KMS key only — no other access.

resource "aws_iam_role" "lakeformation_register" {
  count = var.create_lakeformation_register_role ? 1 : 0

  name = "${var.role_prefix}-lakeformation-register"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLakeFormationAssume"
        Effect = "Allow"
        Principal = {
          Service = "lakeformation.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "lakeformation_register" {
  count = var.create_lakeformation_register_role ? 1 : 0

  name = "${var.role_prefix}-lakeformation-register"
  role = aws_iam_role.lakeformation_register[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "MetadataPrefixAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.data_lake.arn,
          "${aws_s3_bucket.data_lake.arn}/${var.metadata_prefix}*"
        ]
      },
      {
        Sid    = "DataLakeKeyAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.data_lake.arn
      }
    ]
  })
}

locals {
  lakeformation_register_role_arn = var.create_lakeformation_register_role ? aws_iam_role.lakeformation_register[0].arn : var.lakeformation_register_role_arn
}

resource "aws_lakeformation_resource" "metadata" {
  arn      = "${aws_s3_bucket.data_lake.arn}/${var.metadata_prefix}"
  role_arn = local.lakeformation_register_role_arn
}
