# W3 Progress

## Completed

- Terraform foundation: VPC, subnets, ECR, RDS, Redis
- Dockerfiles and ECR image publishing scripts
- ECR force delete for safe `terraform destroy`
- ECS Fargate module for producer and enrichment
- ALB for producer HTTP ingress
- Cloud Map private DNS for enrichment service discovery

## Current caveat

Kafka/MSK is not provisioned yet. Producer can be deployed and health-checked through ALB, but full HTTP -> Kafka publish path needs the next Kafka infrastructure step.

## Next

- Add Kafka infra decision: MSK vs self-managed Kafka on ECS/EC2
- Add consumer deployment path after Kafka exists
- Wire consumer gRPC target to `enrichment.event-pipeline-demo-dev.local:9090`
