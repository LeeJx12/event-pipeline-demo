variable "name_prefix" {
  type        = string
  description = "Name prefix for Redis resources."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for Redis subnet group."
}

variable "allowed_app_cidr" {
  type        = string
  description = "CIDR allowed to access Redis."
}
