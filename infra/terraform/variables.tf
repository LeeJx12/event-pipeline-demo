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
