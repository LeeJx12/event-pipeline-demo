# W3 Terraform Foundation

First AWS foundation for `event-pipeline-demo`.

Creates:

- VPC
- 2 public subnets
- 2 private subnets
- Internet Gateway
- route tables
- ECR repositories for producer, consumer, enrichment
- RDS PostgreSQL dev instance
- ElastiCache Redis dev cluster

Deliberately not included yet:

- NAT Gateway, because it burns hourly cost
- ECS services
- EKS cluster
- MSK Kafka

## Usage

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
# edit db_password
terraform init
terraform plan
terraform apply
```

Destroy after verification:

```bash
terraform destroy
```

## Cost note

This is still not free. RDS and ElastiCache cost money while running. Destroy after validation during side-project work.
