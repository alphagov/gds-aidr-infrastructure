variable "environment_name" {
  type = string
}

variable "distribution_name" {
  type = string
}

variable "alb_dns_name" {
  type = string
}

variable "alb_arn" {
  type = string
}

variable "alb_security_group_id" {
  type = string
}

variable "allowed_countries" {
  type    = list(string)
  default = ["GB"]
}

variable "rate_limit_per_5min" {
  type    = number
  default = 2000
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "team_token" {
  type      = string
  sensitive = true
}
