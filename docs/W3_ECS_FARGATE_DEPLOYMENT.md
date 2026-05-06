# W3-3 ECS Fargate Deployment

## Scope

This patch adds ECS Fargate deployment for:

- producer behind a public ALB on port 80 -> container port 9080
- enrichment as an internal ECS service registered in AWS Cloud Map

Cloud Map DNS:

```txt
enrichment.<project>-<env>.local
```

For the default config:

```txt
enrichment.event-pipeline-demo-dev.local
```

## Important limitation

MSK/Kafka is not provisioned yet. The producer task can boot and pass ALB health checks, but actual event publishing still needs a real Kafka bootstrap server. Keep `kafka_bootstrap_servers = "not-configured:9092"` until the Kafka work starts.

## Apply

```bash
export AWS_PROFILE=leejx2
export AWS_REGION=ap-northeast-2

cd infra/terraform
terraform init
terraform apply
```

If you pushed git-SHA images instead of `dev-latest`, set this in `terraform.tfvars`:

```hcl
image_tag = "<git-sha>"
```

## Check outputs

```bash
terraform output producer_url
terraform output enrichment_cloud_map_dns
terraform output ecs_cluster_name
```

## Check ECS service state

```bash
aws ecs list-services \
  --cluster event-pipeline-demo-dev-cluster \
  --region ap-northeast-2

aws ecs describe-services \
  --cluster event-pipeline-demo-dev-cluster \
  --services event-pipeline-demo-dev-producer event-pipeline-demo-dev-enrichment \
  --query 'services[].{name:serviceName,running:runningCount,desired:desiredCount,status:status}' \
  --output table
```

## Check ALB health

```bash
PRODUCER_URL=$(terraform output -raw producer_url)
curl -i "$PRODUCER_URL/actuator/health"
```

Expected:

```json
{"status":"UP"}
```

## Logs

```bash
aws logs tail /ecs/event-pipeline-demo-dev/producer \
  --follow \
  --region ap-northeast-2

aws logs tail /ecs/event-pipeline-demo-dev/enrichment \
  --follow \
  --region ap-northeast-2
```

## Cost control

This adds cost-bearing resources:

- ALB
- ECS Fargate tasks
- CloudWatch logs
- RDS / Redis from the previous foundation step

When done:

```bash
terraform destroy
```
