variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "name_prefix" {
  description = "Name prefix"
  type        = string
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for EKS control plane and managed node group"
  type        = list(string)
}

variable "node_instance_types" {
  description = "EKS node group instance types"
  type        = list(string)
}

variable "node_desired_size" {
  description = "Desired node count"
  type        = number
}

variable "node_min_size" {
  description = "Minimum node count"
  type        = number
}

variable "node_max_size" {
  description = "Maximum node count"
  type        = number
}
