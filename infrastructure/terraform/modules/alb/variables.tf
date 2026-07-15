# alb/variables.tf

variable "environment_name" {
  description = "Snake Case environment name used in resource Name tags, e.g. Development."
  type        = string
}

variable "alb_name" {
  description = "Name of the load balancer."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID the load balancer and target group live in."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs the load balancer is placed in, one per AZ."
  type        = list(string)
}

variable "security_group_id" {
  description = "ID of the existing alb security group from the vpc module. This module does not create its own security group."
  type        = string
}

variable "port_80_enabled" {
  description = "Whether to add a port 80 ingress rule to the existing alb security group. Only needed while no ACM certificate exists yet."
  type        = bool
  default     = true
}

variable "target_port" {
  description = "Port the target (ECS service) listens on."
  type        = number
  default     = 80
}

variable "target_type" {
  description = "Target type for the target group. 'ip' is required for Fargate awsvpc networking."
  type        = string
  default     = "ip"
}

variable "health_check_path" {
  description = "Path the load balancer polls to check target health."
  type        = string
  default     = "/"
}

variable "health_check_interval" {
  description = "Seconds between health checks."
  type        = number
  default     = 30
}

variable "healthy_threshold" {
  description = "Consecutive successful checks before a target is considered healthy."
  type        = number
  default     = 3
}

variable "unhealthy_threshold" {
  description = "Consecutive failed checks before a target is considered unhealthy."
  type        = number
  default     = 3
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for the HTTPS listener. Null means no HTTPS listener is created yet — HTTP only."
  type        = string
  default     = null
}

variable "redirect_http_to_https" {
  description = "Whether the HTTP listener redirects to HTTPS instead of forwarding to the target group. Only takes effect when acm_certificate_arn is set."
  type        = bool
  default     = false
}

variable "enable_deletion_protection" {
  description = "Whether to enable deletion protection on the load balancer. Recommended true for Production once stable."
  type        = bool
  default     = false
}

variable "idle_timeout" {
  description = "Idle timeout in seconds for connections through the load balancer."
  type        = number
  default     = 60
}

variable "tags" {
  description = "Tags applied to the load balancer and target group."
  type        = map(string)
  default     = {}
}
