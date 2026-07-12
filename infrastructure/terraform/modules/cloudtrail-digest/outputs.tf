# cloudtrail-digest/outputs.tf

output "lambda_function_arn" {
  description = "ARN of the CloudTrail digest Lambda function."
  value       = aws_lambda_function.digest.arn
}

output "lambda_function_name" {
  description = "Name of the CloudTrail digest Lambda function."
  value       = aws_lambda_function.digest.function_name
}

output "eventbridge_rule_arn" {
  description = "ARN of the weekly EventBridge rule."
  value       = aws_cloudwatch_event_rule.weekly.arn
}
