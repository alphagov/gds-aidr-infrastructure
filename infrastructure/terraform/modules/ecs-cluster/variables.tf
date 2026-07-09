# ecs-cluster/variables.tf

variable "environment_name" {
  description = "Snake Case environment name used in resource Name tags, e.g. Development."
  type        = string
}

variable "cluster_name" {
  description = "Name of the ECS cluster."
  type        = string
}

variable "enable_container_insights" {
  description = "Whether to enable CloudWatch Container Insights for the cluster."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to the cluster."
  type        = map(string)
  default     = {}
}
