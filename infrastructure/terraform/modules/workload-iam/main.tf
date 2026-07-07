# workload-iam/main.tf
#
# Creates two IAM roles per workload: an execution role (ECS agent — pulls
# the image, writes logs, decrypts injected secrets) and a task role (the
# application's own runtime permissions). These are always separate
# principals — the execution role never gains application permissions, and
# the task role never gains infrastructure permissions.
#
# Distinct from the six human-role taxonomy in iam-centralised. Trust here
# is scoped to the ECS service principal, not to gds-users.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_iam_policy_document" "ecs_tasks_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# --------------------------------------------------------------------------
# Execution role
# --------------------------------------------------------------------------
# Used by the ECS agent itself, not the application. Pulls the container
# image from ECR, writes container logs to CloudWatch, and optionally
# decrypts injected secrets.

resource "aws_iam_role" "execution" {
  name = "${var.role_prefix}-${var.workload_name}-execution"

  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = merge(var.tags, {
    Name = "${var.role_prefix}-${var.workload_name}-execution"
  })
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "execution_secrets" {
  count = length(var.execution_role_secrets_arns) > 0 ? 1 : 0

  statement {
    sid       = "ReadInjectedSecrets"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = var.execution_role_secrets_arns
  }

  dynamic "statement" {
    for_each = length(var.execution_role_kms_key_arns) > 0 ? [1] : []
    content {
      sid       = "DecryptInjectedSecrets"
      effect    = "Allow"
      actions   = ["kms:Decrypt"]
      resources = var.execution_role_kms_key_arns
    }
  }
}

resource "aws_iam_role_policy" "execution_secrets" {
  count = length(var.execution_role_secrets_arns) > 0 ? 1 : 0

  name   = "${var.role_prefix}-${var.workload_name}-execution-secrets"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution_secrets[0].json
}

# --------------------------------------------------------------------------
# Task role
# --------------------------------------------------------------------------
# Used by the application code running inside the container. No permissions
# by default — supplied per workload via task_role_policy_json.

resource "aws_iam_role" "task" {
  name = "${var.role_prefix}-${var.workload_name}-task"

  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = merge(var.tags, {
    Name = "${var.role_prefix}-${var.workload_name}-task"
  })
}

resource "aws_iam_role_policy" "task_custom" {
  count = var.task_role_policy_json != null ? 1 : 0

  name   = "${var.role_prefix}-${var.workload_name}-task-policy"
  role   = aws_iam_role.task.id
  policy = var.task_role_policy_json
}
