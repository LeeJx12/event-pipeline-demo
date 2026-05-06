output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "producer_ecr_repository_url" {
  value = module.ecr.repository_urls["producer"]
}

output "consumer_ecr_repository_url" {
  value = module.ecr.repository_urls["consumer"]
}

output "enrichment_ecr_repository_url" {
  value = module.ecr.repository_urls["enrichment"]
}

output "rds_endpoint" {
  value = module.rds.endpoint
}

output "rds_port" {
  value = module.rds.port
}

output "redis_endpoint" {
  value = module.redis.endpoint
}

output "redis_port" {
  value = module.redis.port
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "producer_alb_dns_name" {
  value = module.ecs.alb_dns_name
}

output "producer_url" {
  value = "http://${module.ecs.alb_dns_name}"
}

output "enrichment_cloud_map_dns" {
  value = module.ecs.enrichment_dns_name
}

output "ecs_service_security_group_id" {
  value = module.ecs.service_security_group_id
}
