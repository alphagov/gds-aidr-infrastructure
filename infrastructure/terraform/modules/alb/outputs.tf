output "alb_arn" {
  value = aws_lb.this.arn
}

output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "alb_zone_id" {
  value = aws_lb.this.zone_id
}

output "target_group_arn" {
  value = aws_lb_target_group.this.arn
}

output "additional_target_group_arns" {
  value = { for name, tg in aws_lb_target_group.additional : name => tg.arn }
}

output "http_listener_arn" {
  value = aws_lb_listener.http.arn
}
