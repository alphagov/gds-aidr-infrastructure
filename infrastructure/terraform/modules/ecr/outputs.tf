# ecr/outputs.tf

output "repository_url" {
  description = "URL used to push and pull images, e.g. for docker login and docker push."
  value       = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "ARN of the repository, used in IAM policies."
  value       = aws_ecr_repository.this.arn
}

output "repository_name" {
  description = "Name of the repository."
  value       = aws_ecr_repository.this.name
}
