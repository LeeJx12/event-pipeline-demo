variable "name_prefix" {
  type        = string
  description = "Name prefix for ECS resources."
}

variable "aws_region" {
  type        = string
  description = "AWS region."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID."
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs for ALB and public Fargate tasks."
}

variable "producer_image" {
  type        = string
  description = "Full producer image URI."
}

variable "enrichment_image" {
  type        = string
  description = "Full enrichment image URI."
}

variable "desired_count" {
  type        = number
  description = "Desired count for each service."
}

variable "producer_cpu" {
  type        = number
  description = "Producer CPU units."
}

variable "producer_memory" {
  type        = number
  description = "Producer memory MiB."
}

variable "enrichment_cpu" {
  type        = number
  description = "Enrichment CPU units."
}

variable "enrichment_memory" {
  type        = number
  description = "Enrichment memory MiB."
}

variable "kafka_bootstrap_servers" {
  type        = string
  description = "Kafka bootstrap servers for producer."
}

variable "db_host" {
  type        = string
  description = "PostgreSQL host."
}

variable "db_port" {
  type        = number
  description = "PostgreSQL port."
}

variable "db_name" {
  type        = string
  description = "PostgreSQL database name."
}

variable "db_username" {
  type        = string
  description = "PostgreSQL username."
}

variable "db_password" {
  type        = string
  description = "PostgreSQL password."
  sensitive   = true
}

variable "redis_host" {
  type        = string
  description = "Redis host."
}

variable "redis_port" {
  type        = number
  description = "Redis port."
}
