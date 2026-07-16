# rds-postgres/main.tf
#
# Single-instance RDS PostgreSQL, in the private-data subnets already
# reserved for this by the vpc module. Reuses the existing private_data
# security group rather than creating a second one. Credentials are
# generated and stored in Secrets Manager — never in plain Terraform
# variables, never in an environment variable in the task definition.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

resource "random_password" "master" {
  length  = 32
  special = false
}

resource "aws_db_subnet_group" "this" {
  name       = "${lower(var.environment_name)}-${var.identifier}"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${lower(var.environment_name)}-${var.identifier}-subnet-group"
  })
}

resource "aws_db_instance" "this" {
  identifier     = "${lower(var.environment_name)}-${var.identifier}"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_encrypted = true

  db_name  = var.db_name
  username = var.master_username
  password = random_password.master.result

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = false

  multi_az                = var.multi_az
  deletion_protection     = var.deletion_protection
  skip_final_snapshot     = var.skip_final_snapshot
  backup_retention_period = var.backup_retention_days

  tags = merge(var.tags, {
    Name = "${lower(var.environment_name)}-${var.identifier}"
  })
}

resource "aws_secretsmanager_secret" "this" {
  name = "${lower(var.environment_name)}-${var.identifier}-credentials"

  tags = merge(var.tags, {
    Name = "${lower(var.environment_name)}-${var.identifier}-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id = aws_secretsmanager_secret.this.id

  secret_string = jsonencode({
    username = var.master_username
    password = random_password.master.result
    host     = aws_db_instance.this.address
    port     = aws_db_instance.this.port
    dbname   = var.db_name
    url      = "postgresql://${var.master_username}:${random_password.master.result}@${aws_db_instance.this.address}:${aws_db_instance.this.port}/${var.db_name}"
  })
}
