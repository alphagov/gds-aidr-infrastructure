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

variable "aliases" {
  description = "List of custom domain names (CNAMEs) to associate with this CloudFront distribution. Leave empty to use the default *.cloudfront.net domain only."
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for the custom domain(s). Must be in us-east-1. Leave null to use the CloudFront default certificate."
  type        = string
  default     = null
}
