# budget-alerts/outputs.tf

output "budget_id" {
  description = "ID of the monthly budget."
  value       = aws_budgets_budget.monthly.id
}

output "budget_name" {
  description = "Name of the monthly budget."
  value       = aws_budgets_budget.monthly.name
}
