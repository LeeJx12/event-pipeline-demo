output "eks_cluster_name" {
  description = "EKS cluster name for consumer"
  value       = var.enable_eks_consumer ? module.eks[0].cluster_name : null
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = var.enable_eks_consumer ? module.eks[0].cluster_endpoint : null
}

output "eks_node_security_group_id" {
  description = "EKS node security group id"
  value       = var.enable_eks_consumer ? module.eks[0].node_security_group_id : null
}
