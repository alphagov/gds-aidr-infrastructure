# workload-iam/outputs.tf

output "execution_role_arn" {
  description = "ARN of the execution role. Used as executionRoleArn in the ECS task definition."
  value       = aws_iam_role.execution.arn
}

output "execution_role_name" {
  description = "Name of the execution role."
  value       = aws_iam_role.execution.name
}

output "task_role_arn" {
  description = "ARN of the task role. Used as taskRoleArn in the ECS task definition."
  value       = aws_iam_role.task.arn
}

output "task_role_name" {
  description = "Name of the task role."
  value       = aws_iam_role.task.name
}
