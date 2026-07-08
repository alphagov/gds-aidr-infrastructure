# ecs-fargate-service/variables.tf

variable "environment_name" {
  description = "Snake Case environment name used in resource Name tags, e.g. Development."
  type        = string
}

variable "service_name" {
  description = "Name of the service and task definition family."
  type        = string
}

variable "cluster_arn" {
  description = "ARN of the ECS cluster to run this service or task on."
  type        = string
}

variable "execution_role_arn" {
  description = "ARN of the execution role, from the workload-iam module."
  type        = string
}

variable "task_role_arn" {
  description = "ARN of the task role, from the workload-iam module."
  type        = string
}

variable "container_image" {
  description = "Full container image URI, including tag, e.g. an ECR repository URL with a tag."
  type        = string
}

variable "container_port" {
  description = "Port the container listens on. Null means no port mapping is configured."
  type        = number
  default     = null
}

variable "cpu" {
  description = "Task-level CPU units, per Fargate's allowed CPU/memory combinations."
  type        = number
  default     = 256
}

variable "memory" {
  description = "Task-level memory in MiB, per Fargate's allowed CPU/memory combinations."
  type        = number
  default     = 512
}

variable "environment_variables" {
  description = "Environment variables passed to the container. List of objects with name and value."
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "subnet_ids" {
  description = "Subnet IDs the task or service runs in. Private-app subnets from the networking module."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs attached to the task ENI. The ecs_task security group from the networking module."
  type        = list(string)
}

variable "assign_public_ip" {
  description = "Whether the task gets a public IP. False for private-app subnets routed via NAT."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch log group retention in days."
  type        = number
  default     = 30
}

variable "create_service" {
  description = "Whether to create an aws_ecs_service for this task definition. False means only the task definition is created, for later use with RunTask or EventBridge Scheduler."
  type        = bool
  default     = true
}

variable "desired_count" {
  description = "Desired number of running tasks. Only used when create_service is true."
  type        = number
  default     = 1
}

variable "tags" {
  description = "Tags applied to the task definition, service, and log group."
  type        = map(string)
  default     = {}
}
