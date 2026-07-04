# vpc/main.tf
#
# Creates a three-tier VPC (public, private-app, private-data) in a single
# account. Called once per account (development, staging, production) from
# the networking environment using provider aliases.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_region" "current" {}

# --------------------------------------------------------------------------
# VPC
# --------------------------------------------------------------------------

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "${lower(var.environment_name)}-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${lower(var.environment_name)}-igw"
  })
}

# --------------------------------------------------------------------------
# Public subnets
# --------------------------------------------------------------------------
# NAT Gateway(s) and future ALB only. No workloads run here.

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.this.id
  cidr_block               = var.public_subnet_cidrs[count.index]
  availability_zone        = var.azs[count.index]
  map_public_ip_on_launch  = true

  tags = merge(var.tags, {
    Name = "${lower(var.environment_name)}-public-${var.azs[count.index]}"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.tags, {
    Name = "${lower(var.environment_name)}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --------------------------------------------------------------------------
# NAT gateways
# --------------------------------------------------------------------------
# One EIP + NAT gateway per var.nat_gateway_count, placed in public subnets.
# Development uses 1 (cost-conscious). Staging and Production use one per AZ.

resource "aws_eip" "nat" {
  count = var.nat_gateway_count

  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${lower(var.environment_name)}-nat-eip-${count.index}"
  })
}

resource "aws_nat_gateway" "this" {
  count = var.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, {
    Name = "${lower(var.environment_name)}-nat-${count.index}"
  })

  depends_on = [aws_internet_gateway.this]
}

# --------------------------------------------------------------------------
# Private-app subnets
# --------------------------------------------------------------------------
# ECS Fargate tasks, Lambda functions, Glue ETL jobs. Routed to a NAT gateway
# for OS updates only; AWS service traffic uses VPC endpoints below.
# Route table count matches subnet count. When nat_gateway_count is 1, all
# route tables point at the same NAT gateway. When it matches AZ count, each
# route table points at its own AZ's NAT gateway.

resource "aws_subnet" "private_app" {
  count = length(var.private_app_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_app_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(var.tags, {
    Name = "${lower(var.environment_name)}-private-app-${var.azs[count.index]}"
  })
}

resource "aws_route_table" "private_app" {
  count = length(var.private_app_subnet_cidrs)

  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index % var.nat_gateway_count].id
  }

  tags = merge(var.tags, {
    Name = "${lower(var.environment_name)}-private-app-rt-${var.azs[count.index]}"
  })
}

resource "aws_route_table_association" "private_app" {
  count = length(aws_subnet.private_app)

  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app[count.index].id
}

# --------------------------------------------------------------------------
# Private-data subnets
# --------------------------------------------------------------------------
# Redshift, Aurora. No internet route at all. Accessible only from
# private-app security groups.

resource "aws_subnet" "private_data" {
  count = length(var.private_data_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_data_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(var.tags, {
    Name = "${lower(var.environment_name)}-private-data-${var.azs[count.index]}"
  })
}

resource "aws_route_table" "private_data" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${lower(var.environment_name)}-private-data-rt"
  })
}

resource "aws_route_table_association" "private_data" {
  count = length(aws_subnet.private_data)

  subnet_id      = aws_subnet.private_data[count.index].id
  route_table_id = aws_route_table.private_data.id
}

# --------------------------------------------------------------------------
# Security groups
# --------------------------------------------------------------------------
# One security group per logical role. Ingress rules are added by the
# services that use each group (ECS module, future ALB, future Redshift
# module). Default deny — no ingress defined here beyond what each group
# needs to talk to the others.

resource "aws_security_group" "vpc_endpoints" {
  name        = "${lower(var.environment_name)}-vpc-endpoints"
  description = "Allows HTTPS traffic from the VPC to interface VPC endpoints."
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from within the VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${lower(var.environment_name)}-vpc-endpoints-sg"
  })
}

resource "aws_security_group" "ecs_task" {
  name        = "${lower(var.environment_name)}-ecs-task"
  description = "Attached to ECS Fargate tasks. No ingress by default."
  vpc_id      = aws_vpc.this.id

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${lower(var.environment_name)}-ecs-task-sg"
  })
}

resource "aws_security_group" "private_data" {
  name        = "${lower(var.environment_name)}-private-data"
  description = "Attached to future Redshift or Aurora resources. Ingress restricted to the ECS task security group."
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "Data-layer traffic from ECS tasks"
    from_port        = 0
    to_port           = 0
    protocol          = "-1"
    security_groups   = [aws_security_group.ecs_task.id]
  }

  tags = merge(var.tags, {
    Name = "${lower(var.environment_name)}-private-data-sg"
  })
}

resource "aws_security_group" "alb" {
  name        = "${lower(var.environment_name)}-alb"
  description = "Reserved for a future Application Load Balancer. No listeners exist yet."
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from the internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${lower(var.environment_name)}-alb-sg"
  })
}

# --------------------------------------------------------------------------
# VPC endpoints — gateway type (free, attached via route table)
# --------------------------------------------------------------------------

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private_app[*].id

  tags = merge(var.tags, {
    Name = "${lower(var.environment_name)}-vpce-s3"
  })
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private_app[*].id

  tags = merge(var.tags, {
    Name = "${lower(var.environment_name)}-vpce-dynamodb"
  })
}

# --------------------------------------------------------------------------
# VPC endpoints — interface type (billed hourly, attached to subnets)
# --------------------------------------------------------------------------

locals {
  interface_endpoint_services = [
    "ecr.api",
    "ecr.dkr",
    "secretsmanager",
    "logs",
    "kms",
    "bedrock",
    "bedrock-runtime",
    "sts",
    "ssm",
  ]
}

resource "aws_vpc_endpoint" "interface" {
  for_each = var.create_interface_endpoints ? toset(local.interface_endpoint_services) : toset([])

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.value}"
  vpc_endpoint_type    = "Interface"
  subnet_ids           = aws_subnet.private_app[*].id
  security_group_ids   = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled  = true

  tags = merge(var.tags, {
    Name = "${lower(var.environment_name)}-vpce-${each.value}"
  })
}