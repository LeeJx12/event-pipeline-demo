output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "producer_service_name" {
  value = aws_ecs_service.producer.name
}

output "enrichment_service_name" {
  value = aws_ecs_service.enrichment.name
}

output "alb_dns_name" {
  value = aws_lb.producer.dns_name
}

output "alb_arn" {
  value = aws_lb.producer.arn
}

output "cloud_map_namespace_name" {
  value = aws_service_discovery_private_dns_namespace.this.name
}

output "enrichment_dns_name" {
  value = local.enrichment_dns_name
}

output "service_security_group_id" {
  value = aws_security_group.service.id
}
