# budget-alerts/variables.tf
# budget limits set per environment and in infrastructure/terraform/environments/production-iam/terraform.tfvars (centrally-maintained)
variable "budget_prefix" {
  description = "Prefix for the budget name, e.g. 'gds-aidr-development'."
  type        = string
}

variable "monthly_limit_usd" {
  description = "Monthly budget limit in USD."
  type        = string
}

variable "alert_emails" {
  description = "List of email addresses to receive budget alerts."
  type        = list(string)
}

variable "tags" {
  description = "Tags applied to the budget resource."
  type        = map(string)
  default     = {}
}
