variable "aws_region" {
  description = "AWS region for the dev environment."
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "Project name used for resource naming."
  type        = string
  default     = "event-pipeline-demo"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones to use. Keep this to two AZs for dev cost control."
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "db_username" {
  description = "PostgreSQL master username."
  type        = string
  default     = "pipeline"
}

variable "db_password" {
  description = "PostgreSQL master password. Pass via terraform.tfvars or TF_VAR_db_password."
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Initial PostgreSQL database name."
  type        = string
  default     = "pipeline"
}

variable "allowed_app_cidr" {
  description = "CIDR allowed to access internal data stores. For W3 foundation, default is VPC-only."
  type        = string
  default     = "10.20.0.0/16"
}

variable "image_tag" {
  description = "Docker image tag to deploy from ECR. Use dev-latest or a git SHA tag."
  type        = string
  default     = "dev-latest"
}

variable "ecs_desired_count" {
  description = "Desired task count per ECS service for dev."
  type        = number
  default     = 1
}

variable "producer_cpu" {
  description = "Producer task CPU units."
  type        = number
  default     = 512
}

variable "producer_memory" {
  description = "Producer task memory MiB."
  type        = number
  default     = 1024
}

variable "enrichment_cpu" {
  description = "Enrichment task CPU units."
  type        = number
  default     = 512
}

variable "enrichment_memory" {
  description = "Enrichment task memory MiB."
  type        = number
  default     = 1024
}

variable "kafka_bootstrap_servers" {
  description = "Kafka bootstrap servers for producer. MSK is not added yet, so keep a placeholder until W3/W4 Kafka work."
  type        = string
  default     = "not-configured:9092"
}

variable "aws_profile" {
  description = "AWS CLI profile name used by Terraform"
  type        = string
  default     = "leejx2"
}

variable "aws_account_id" {
  description = "Expected AWS account ID. Terraform fails if credentials point to another account."
  type        = string
}

variable "kafka_image" {
  description = "Dev-only single-node Kafka image for ECS/Fargate."
  type        = string
  default     = "confluentinc/cp-kafka:7.7.1"
}

variable "kafka_cpu" {
  description = "Kafka task CPU units."
  type        = number
  default     = 1024
}

variable "kafka_memory" {
  description = "Kafka task memory MiB."
  type        = number
  default     = 2048
}

variable "kafka_desired_count" {
  description = "Desired count for dev Kafka. Keep this at 1 because this is a single-node KRaft broker."
  type        = number
  default     = 1
}

variable "kafka_cluster_id" {
  description = "Static KRaft cluster ID for the dev Kafka container."
  type        = string
  default     = "MkU3OEVBNTcwNTJENDM2Qk"
}

variable "kafka_num_partitions" {
  description = "Default number of Kafka partitions for auto-created topics."
  type        = number
  default     = 6
}
