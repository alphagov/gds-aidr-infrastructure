# rds-postgres/variables.tf

variable "environment_name" {
  description = "Snake Case environment name used in resource Name tags, e.g. Development."
  type        = string
}

variable "identifier" {
  description = "RDS instance identifier."
  type        = string
}

variable "engine_version" {
  description = "PostgreSQL engine version."
  type        = string
  default     = "15"
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Storage in GB."

  type    = number
  default = 20
}

variable "db_name" {
  description = "Initial database name created on the instance."
  type        = string
}

variable "master_username" {
  description = "Master username for the database."
  type        = string
  default     = "postgres"
}

variable "vpc_id" {
  description = "VPC ID the DB subnet group is created in."
  type        = string
}

variable "subnet_ids" {
  description = "Private-data subnet IDs from the networking module."
  type        = list(string)
}

variable "security_group_id" {
  description = "ID of the existing private_data security group from the vpc module. No new security group is created."
  type        = string
}

variable "multi_az" {
  description = "Whether to run a standby in a second AZ. False for Development, true recommended for Production."
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection. Recommended true once past the demo phase."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Whether to skip taking a final snapshot on destroy. True for Development, false for Production."
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Days to retain automated backups."
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags applied to all resources created by this module."
  type        = map(string)
  default     = {}
}
