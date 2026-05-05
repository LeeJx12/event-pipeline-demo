variable "name_prefix" {
  type        = string
  description = "Name prefix for resources."
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block."
}

variable "availability_zones" {
  type        = list(string)
  description = "AZs for subnets."
}
