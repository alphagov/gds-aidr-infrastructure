# environments/networking/variables.tf

# --------------------------------------------------------------------------
# Account IDs
# --------------------------------------------------------------------------

variable "development_account_id" {
  description = "AWS account ID for the development account."
  type        = string
}

variable "staging_account_id" {
  description = "AWS account ID for the staging account."
  type        = string
}

variable "production_account_id" {
  description = "AWS account ID for the production account."
  type        = string
}

variable "role_prefix" {
  description = "Prefix for IAM role names, used to reference the existing terraform role created by production-iam."
  type        = string
  default     = "gds-aidr"
}

# --------------------------------------------------------------------------
# Shared
# --------------------------------------------------------------------------

variable "azs" {
  description = "Availability zones to spread subnets across, applied to all three accounts."
  type        = list(string)
  default     = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
}

# --------------------------------------------------------------------------
# Development
# --------------------------------------------------------------------------

variable "development_vpc_cidr" {
  description = "VPC CIDR block for the development account."
  type        = string
  default     = "10.2.0.0/16"
}

variable "development_public_subnet_cidrs" {
  type    = list(string)
  default = ["10.2.0.0/24", "10.2.1.0/24", "10.2.2.0/24"]
}

variable "development_private_app_subnet_cidrs" {
  type    = list(string)
  default = ["10.2.4.0/23", "10.2.6.0/23", "10.2.8.0/23"]
}

variable "development_private_data_subnet_cidrs" {
  type    = list(string)
  default = ["10.2.10.0/23", "10.2.12.0/23", "10.2.14.0/23"]
}

# --------------------------------------------------------------------------
# Staging
# --------------------------------------------------------------------------

variable "staging_vpc_cidr" {
  description = "VPC CIDR block for the staging account."
  type        = string
  default     = "10.1.0.0/16"
}

variable "staging_public_subnet_cidrs" {
  type    = list(string)
  default = ["10.1.0.0/24", "10.1.1.0/24", "10.1.2.0/24"]
}

variable "staging_private_app_subnet_cidrs" {
  type    = list(string)
  default = ["10.1.4.0/23", "10.1.6.0/23", "10.1.8.0/23"]
}

variable "staging_private_data_subnet_cidrs" {
  type    = list(string)
  default = ["10.1.10.0/23", "10.1.12.0/23", "10.1.14.0/23"]
}

# --------------------------------------------------------------------------
# Production
# --------------------------------------------------------------------------

variable "production_vpc_cidr" {
  description = "VPC CIDR block for the production account."
  type        = string
  default     = "10.0.0.0/16"
}

variable "production_public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
}

variable "production_private_app_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.4.0/23", "10.0.6.0/23", "10.0.8.0/23"]
}

variable "production_private_data_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.10.0/23", "10.0.12.0/23", "10.0.14.0/23"]
}
