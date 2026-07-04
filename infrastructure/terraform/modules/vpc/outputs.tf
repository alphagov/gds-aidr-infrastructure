# vpc/outputs.tf

output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "IDs of the private-app subnets."
  value       = aws_subnet.private_app[*].id
}

output "private_data_subnet_ids" {
  description = "IDs of the private-data subnets."
  value       = aws_subnet.private_data[*].id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT gateways."
  value       = aws_nat_gateway.this[*].id
}

output "ecs_task_security_group_id" {
  description = "ID of the security group attached to ECS Fargate tasks."
  value       = aws_security_group.ecs_task.id
}

output "private_data_security_group_id" {
  description = "ID of the security group for future Redshift or Aurora resources."
  value       = aws_security_group.private_data.id
}

output "vpc_endpoints_security_group_id" {
  description = "ID of the security group attached to interface VPC endpoints."
  value       = aws_security_group.vpc_endpoints.id
}

output "alb_security_group_id" {
  description = "ID of the security group reserved for a future Application Load Balancer."
  value       = aws_security_group.alb.id
}

output "s3_vpc_endpoint_id" {
  description = "ID of the S3 gateway VPC endpoint. Used later for datalake bucket policy network-path restrictions."
  value       = aws_vpc_endpoint.s3.id
}
