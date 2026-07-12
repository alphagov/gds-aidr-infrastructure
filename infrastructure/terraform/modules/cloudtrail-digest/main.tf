# cloudtrail-digest/main.tf
#
# Creates a Lambda function triggered weekly by EventBridge that queries
# CloudTrail for team role activity and publishes a summary to SNS.
# Called once per account from the monitoring environment using provider
# aliases.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# --------------------------------------------------------------------------
# Lambda execution role
# --------------------------------------------------------------------------
# Allows the Lambda to read CloudTrail events, publish to the SNS topic
# in Production, and write its own CloudWatch logs.

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name = "${var.role_prefix}-cloudtrail-digest-${lower(var.account_label)}"

  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json

  tags = var.tags
}

data "aws_iam_policy_document" "lambda_permissions" {
  # CloudTrail read
  statement {
    sid    = "ReadCloudTrail"
    effect = "Allow"
    actions = [
      "cloudtrail:LookupEvents"
    ]
    resources = ["*"]
  }

  # SNS publish (cross-account to Production)
  statement {
    sid    = "PublishToSNS"
    effect = "Allow"
    actions = [
      "sns:Publish"
    ]
    resources = [var.sns_topic_arn]
  }

  # CloudWatch Logs
  statement {
    sid    = "WriteLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["${aws_cloudwatch_log_group.lambda.arn}:*"]
  }
}

resource "aws_iam_role_policy" "lambda" {
  name   = "${var.role_prefix}-cloudtrail-digest-policy"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_permissions.json
}

# --------------------------------------------------------------------------
# CloudWatch log group
# --------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.role_prefix}-cloudtrail-digest-${lower(var.account_label)}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# --------------------------------------------------------------------------
# Lambda function
# --------------------------------------------------------------------------

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/cloudtrail_digest.py"
  output_path = "${path.module}/.build/cloudtrail_digest_${lower(var.account_label)}.zip"
}

resource "aws_lambda_function" "digest" {
  function_name    = "${var.role_prefix}-cloudtrail-digest-${lower(var.account_label)}"
  role             = aws_iam_role.lambda.arn
  handler          = "cloudtrail_digest.handler"
  runtime          = "python3.12"
  timeout          = 120
  memory_size      = 256
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      SNS_TOPIC_ARN = var.sns_topic_arn
      ACCOUNT_LABEL = var.account_label
      ROLE_PREFIX   = var.role_prefix
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy.lambda
  ]

  tags = var.tags
}

# --------------------------------------------------------------------------
# EventBridge schedule — every Monday at 08:00 UTC
# --------------------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "weekly" {
  name                = "${var.role_prefix}-cloudtrail-digest-weekly-${lower(var.account_label)}"
  description         = "Triggers CloudTrail digest Lambda every Monday at 08:00 UTC"
  schedule_expression = "cron(0 8 ? * MON *)"

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule = aws_cloudwatch_event_rule.weekly.name
  arn  = aws_lambda_function.digest.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.digest.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.weekly.arn
}
