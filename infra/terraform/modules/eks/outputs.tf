output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_security_group_id" {
  description = "EKS cluster security group id"
  value       = aws_security_group.cluster.id
}

output "node_security_group_id" {
  description = "EKS node security group id"
  value       = aws_security_group.node.id
}

output "node_group_name" {
  description = "EKS managed node group name"
  value       = aws_eks_node_group.consumer.node_group_name
}
