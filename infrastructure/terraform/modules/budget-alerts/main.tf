# budget-alerts/main.tf
#
# Creates an AWS Budget with email notifications at configurable
# thresholds. Called once per account from the production-iam
# environment using provider aliases.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# --------------------------------------------------------------------------
# Monthly Budget
# --------------------------------------------------------------------------
# Tracks actual spend against a monthly limit. Sends email alerts at
# 50%, 80%, and 100% of the budget. Also sends a forecasted alert at
# 100% so you get early warning before the month ends.

resource "aws_budgets_budget" "monthly" {
  name         = "${var.budget_prefix}-monthly-total"
  budget_type  = "COST"
  limit_amount = var.monthly_limit_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Alert at 50% of actual spend
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
  }

  # Alert at 80% of actual spend
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
  }

  # Alert at 100% of actual spend
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
  }

  # Forecasted alert at 100% — early warning before month ends
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.alert_emails
  }

  tags = var.tags
}
