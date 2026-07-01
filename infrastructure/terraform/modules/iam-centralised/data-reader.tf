# iam-centralised/data-reader.tf
#
# Scoped read only role for the synthetic data library. This is the read path
# for consumers who have an AWS identity: internal team roles and
# cross-government accounts. They assume this role and read the dataset and
# metadata prefixes, and nothing else.
#
# External non-government users do NOT use this role. They have no AWS identity
# to federate from and reach the data through the API instead. That path is
# defined in the data backend repository.
#
# This role is read only by design. The write path is the generation task role
# in the data backend repository. No principal both reads and writes.

# --------------------------------------------------------------------------
# Data Reader Role
# --------------------------------------------------------------------------
# Trusted by the accounts in data_reader_trusted_arns. For internal use this is
# the gds-users org root. For cross-government use this is the other
# department's account root, added to the same list. MFA is always required.

resource "aws_iam_role" "data_reader" {
  count = var.create_data_reader_role ? 1 : 0

  name = "${var.role_prefix}-data-reader"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = var.data_reader_trusted_arns
        }
        Action = "sts:AssumeRole"
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      }
    ]
  })

  max_session_duration = var.max_session_duration

  tags = var.tags
}

# Read access scoped to the dataset and metadata prefixes of the data lake
# bucket. ListBucket is scoped with a condition so a caller can only list the
# permitted prefixes, not the whole bucket.

resource "aws_iam_role_policy" "data_reader" {
  count = var.create_data_reader_role ? 1 : 0

  name = "${var.role_prefix}-data-reader"
  role = aws_iam_role.data_reader[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          "${var.data_lake_bucket_arn}/${var.dataset_prefix}*",
          "${var.data_lake_bucket_arn}/${var.metadata_prefix}*"
        ]
      },
      {
        Sid    = "ListPermittedPrefixes"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = var.data_lake_bucket_arn
        Condition = {
          StringLike = {
            "s3:prefix" = [
              "${var.dataset_prefix}*",
              "${var.metadata_prefix}*"
            ]
          }
        }
      }
    ]
  })
}
