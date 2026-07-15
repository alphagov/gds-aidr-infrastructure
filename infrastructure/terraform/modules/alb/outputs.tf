# alb/outputs.tf

output "alb_arn" {
  description = "ARN of the load balancer."
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "DNS name of the load balancer. Works immediately over HTTP, no domain required."
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Route53 hosted zone ID of the load balancer, needed later for an alias record."
  value       = aws_lb.this.zone_id
}

output "target_group_arn" {
  description = "ARN of the default target group. Used as the target_group_arn when creating an ECS service."
  value       = aws_lb_target_group.this.arn
}

output "http_listener_arn" {
  description = "ARN of the HTTP listener."
  value       = aws_lb_listener.http.arn
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener, if created."
  value       = var.acm_certificate_arn != null ? aws_lb_listener.https[0].arn : null
}
