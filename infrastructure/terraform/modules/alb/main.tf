terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_lb" "this" {
  name               = var.alb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.enable_deletion_protection
  idle_timeout               = var.idle_timeout

  tags = merge(var.tags, {
    Name = "${lower(var.environment_name)}-${var.alb_name}"
  })
}

resource "aws_lb_target_group" "this" {
  name        = "${var.alb_name}-default"
  port        = var.target_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = var.target_type

  health_check {
    path                = var.health_check_path
    interval            = var.health_check_interval
    healthy_threshold   = var.healthy_threshold
    unhealthy_threshold = var.unhealthy_threshold
    matcher             = "200"
  }

  tags = merge(var.tags, {
    Name = "${lower(var.environment_name)}-${var.alb_name}-default"
  })
}

resource "aws_lb_target_group" "additional" {
  for_each = { for route in var.additional_routes : route.name => route }

  name        = "${var.alb_name}-${each.value.name}"
  port        = each.value.port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = var.target_type

  health_check {
    path                = each.value.health_check_path
    interval            = var.health_check_interval
    healthy_threshold   = var.healthy_threshold
    unhealthy_threshold = var.unhealthy_threshold
    matcher             = "200"
  }

  tags = merge(var.tags, {
    Name = "${lower(var.environment_name)}-${var.alb_name}-${each.value.name}"
  })
}

resource "aws_security_group_rule" "http_ingress" {
  count = var.port_80_enabled ? 1 : 0

  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = var.security_group_id
  description       = "Temporary HTTP ingress, no ACM certificate yet"
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  dynamic "default_action" {
    for_each = var.acm_certificate_arn != null && var.redirect_http_to_https ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = var.acm_certificate_arn != null && var.redirect_http_to_https ? [] : [1]
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.this.arn
    }
  }
}

resource "aws_lb_listener_rule" "additional" {
  for_each = { for route in var.additional_routes : route.name => route }

  listener_arn = aws_lb_listener.http.arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.additional[each.key].arn
  }

  condition {
    path_pattern {
      values = each.value.path_patterns
    }
  }
}

resource "aws_lb_listener" "https" {
  count = var.acm_certificate_arn != null ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
