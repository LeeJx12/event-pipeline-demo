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
