module "eks" {
  count = var.enable_eks_consumer ? 1 : 0

  source = "./modules/eks"

  project_name       = var.project_name
  environment        = var.environment
  name_prefix        = local.name_prefix
  kubernetes_version = var.eks_kubernetes_version
  subnet_ids         = module.network.public_subnet_ids
  vpc_id             = module.network.vpc_id

  node_instance_types = var.eks_node_instance_types
  node_desired_size   = var.eks_node_desired_size
  node_min_size       = var.eks_node_min_size
  node_max_size       = var.eks_node_max_size
}

# Allow EKS consumer pods/nodes to call ECS-hosted Kafka and Enrichment via Cloud Map.
# Do not modify the ECS module internals; just add cross-SG ingress here.
resource "aws_security_group_rule" "eks_to_ecs_kafka" {
  count = var.enable_eks_consumer ? 1 : 0

  type                     = "ingress"
  description              = "EKS consumer to ECS Kafka"
  security_group_id        = module.ecs.service_security_group_id
  source_security_group_id = module.eks[0].node_security_group_id
  protocol                 = "tcp"
  from_port                = 9092
  to_port                  = 9092
}

resource "aws_security_group_rule" "eks_to_ecs_enrichment_grpc" {
  count = var.enable_eks_consumer ? 1 : 0

  type                     = "ingress"
  description              = "EKS consumer to ECS Enrichment gRPC"
  security_group_id        = module.ecs.service_security_group_id
  source_security_group_id = module.eks[0].node_security_group_id
  protocol                 = "tcp"
  from_port                = 9090
  to_port                  = 9090
}
