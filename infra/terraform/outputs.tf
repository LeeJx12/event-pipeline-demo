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

output "producer_ecr_repository_url" {
  description = "Producer ECR repository URL"
  value       = module.ecr.repository_urls["producer"]
}

output "consumer_ecr_repository_url" {
  description = "Consumer ECR repository URL"
  value       = module.ecr.repository_urls["consumer"]
}

output "enrichment_ecr_repository_url" {
  description = "Enrichment ECR repository URL"
  value       = module.ecr.repository_urls["enrichment"]
}