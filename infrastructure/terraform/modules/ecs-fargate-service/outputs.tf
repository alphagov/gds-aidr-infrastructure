# ecs-fargate-service/outputs.tf

output "task_definition_arn" {
  description = "ARN of the task definition. Used for RunTask or EventBridge Scheduler when create_service is false."
  value       = aws_ecs_task_definition.this.arn
}

output "task_definition_family" {
  description = "Family name of the task definition."
  value       = aws_ecs_task_definition.this.family
}

output "log_group_name" {
  description = "Name of the CloudWatch log group for this task."
  value       = aws_cloudwatch_log_group.this.name
}

output "service_name" {
  description = "Name of the ECS service, if created."
  value       = var.create_service ? aws_ecs_service.this[0].name : null
}
