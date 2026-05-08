variable "enable_eks_consumer" {
  description = "Create EKS cluster for consumer deployment"
  type        = bool
  default     = true
}

variable "eks_kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "eks_node_instance_types" {
  description = "Instance types for the consumer EKS managed node group"
  type        = list(string)
  default     = ["t3.small"]
}

variable "eks_node_desired_size" {
  description = "Desired EKS node count for dev"
  type        = number
  default     = 1
}

variable "eks_node_min_size" {
  description = "Minimum EKS node count for dev"
  type        = number
  default     = 1
}

variable "eks_node_max_size" {
  description = "Maximum EKS node count for dev"
  type        = number
  default     = 3
}
