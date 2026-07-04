# vpc/variables.tf

variable "environment_name" {
  description = "Snake Case environment name used in resource Name tags, e.g. Development."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "azs" {
  description = "Availability zones to spread subnets across."
  type        = list(string)
  default     = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per AZ. No workloads run here."
  type        = list(string)
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for private-app subnets, one per AZ. ECS Fargate, Lambda, Glue."
  type        = list(string)
}

variable "private_data_subnet_cidrs" {
  description = "CIDR blocks for private-data subnets, one per AZ. No internet route."
  type        = list(string)
}

variable "nat_gateway_count" {
  description = "Number of NAT gateways. 1 for cost-conscious single-AZ NAT, matches number of AZs for full high availability."
  type        = number
}

variable "create_interface_endpoints" {
  description = "Whether to create interface VPC endpoints (ECR, Secrets Manager, CloudWatch Logs, KMS, Bedrock, STS, SSM)."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to all resources created by this module."
  type        = map(string)
  default     = {}
}
