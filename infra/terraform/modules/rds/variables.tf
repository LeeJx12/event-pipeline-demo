variable "name_prefix" {
  type        = string
  description = "Name prefix for RDS resources."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for DB subnet group."
}

variable "allowed_app_cidr" {
  type        = string
  description = "CIDR allowed to access PostgreSQL."
}

variable "db_name" {
  type        = string
  description = "Initial database name."
}

variable "db_username" {
  type        = string
  description = "Master username."
}

variable "db_password" {
  type        = string
  description = "Master password."
  sensitive   = true
}
