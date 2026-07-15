# ecs-fargate-service/main.tf
#
# Creates a Fargate task definition, always. Creates an aws_ecs_service only
# when create_service is true. This lets the same module serve a long-running
# service now and a batch task later, without duplicating the task
# definition, log group, or container definition logic.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${lower(var.environment_name)}-${var.service_name}"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = "${lower(var.environment_name)}-${var.service_name}-logs"
  })
}

resource "aws_ecs_task_definition" "this" {
  family                   = "${lower(var.environment_name)}-${var.service_name}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = var.service_name
      image     = var.container_image
      essential = true

      portMappings = var.container_port != null ? [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ] : []

      environment = [
        for env_var in var.environment_variables : {
          name  = env_var.name
          value = env_var.value
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = var.service_name
        }
      }
    }
  ])

  tags = merge(var.tags, {
    Name = "${lower(var.environment_name)}-${var.service_name}"
  })
}

data "aws_region" "current" {}

resource "aws_ecs_service" "this" {
  count = var.create_service ? 1 : 0

  name            = "${lower(var.environment_name)}-${var.service_name}"
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = var.assign_public_ip
  }

  dynamic "load_balancer" {
    for_each = var.target_group_arn != null ? [1] : []
    content {
      target_group_arn = var.target_group_arn
      container_name   = var.service_name
      container_port   = var.container_port
    }
  }

  tags = merge(var.tags, {
    Name = "${lower(var.environment_name)}-${var.service_name}"
  })
}
