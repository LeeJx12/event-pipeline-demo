locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

module "network" {
  source = "./modules/network"

  name_prefix        = local.name_prefix
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

module "ecr" {
  source = "./modules/ecr"

  name_prefix = local.name_prefix
  repositories = [
    "producer",
    "consumer",
    "enrichment"
  ]
}

module "rds" {
  source = "./modules/rds"

  name_prefix      = local.name_prefix
  vpc_id           = module.network.vpc_id
  subnet_ids       = module.network.private_subnet_ids
  allowed_app_cidr = var.allowed_app_cidr
  db_name          = var.db_name
  db_username      = var.db_username
  db_password      = var.db_password
}

module "redis" {
  source = "./modules/redis"

  name_prefix      = local.name_prefix
  vpc_id           = module.network.vpc_id
  subnet_ids       = module.network.private_subnet_ids
  allowed_app_cidr = var.allowed_app_cidr
}

module "ecs" {
  source = "./modules/ecs"

  name_prefix       = local.name_prefix
  environment       = var.environment
  aws_region        = var.aws_region
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids

  producer_image   = "${module.ecr.repository_urls["producer"]}:${var.image_tag}"
  enrichment_image = "${module.ecr.repository_urls["enrichment"]}:${var.image_tag}"

  desired_count             = var.ecs_desired_count
  producer_cpu              = var.producer_cpu
  producer_memory           = var.producer_memory
  enrichment_cpu            = var.enrichment_cpu
  enrichment_memory         = var.enrichment_memory
  kafka_bootstrap_servers   = var.kafka_bootstrap_servers

  kafka_image           = var.kafka_image
  kafka_cpu             = var.kafka_cpu
  kafka_memory          = var.kafka_memory
  kafka_desired_count   = var.kafka_desired_count
  kafka_cluster_id      = var.kafka_cluster_id
  kafka_num_partitions  = var.kafka_num_partitions

  db_host     = module.rds.endpoint
  db_port     = module.rds.port
  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password

  redis_host = module.redis.endpoint
  redis_port = module.redis.port
}
