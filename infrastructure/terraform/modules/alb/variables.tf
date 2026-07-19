variable "environment_name" {
  type = string
}

variable "alb_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "port_80_enabled" {
  type    = bool
  default = true
}

variable "target_port" {
  type    = number
  default = 80
}

variable "target_type" {
  type    = string
  default = "ip"
}

variable "health_check_path" {
  type    = string
  default = "/"
}

variable "health_check_interval" {
  type    = number
  default = 30
}

variable "healthy_threshold" {
  type    = number
  default = 3
}

variable "unhealthy_threshold" {
  type    = number
  default = 3
}

variable "acm_certificate_arn" {
  type    = string
  default = null
}

variable "redirect_http_to_https" {
  type    = bool
  default = false
}

variable "enable_deletion_protection" {
  type    = bool
  default = false
}

variable "idle_timeout" {
  type    = number
  default = 60
}

variable "additional_routes" {
  type = list(object({
    name              = string
    port              = number
    health_check_path = string
    path_patterns     = list(string)
    priority          = number
  }))
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
