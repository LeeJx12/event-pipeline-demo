# W3-5 — EKS Consumer Deployment

Goal: keep the original architecture direction.

```txt
ALB
  -> ECS Producer
  -> ECS Kafka
  -> EKS Consumer
  -> ECS Enrichment via Cloud Map gRPC
  -> RDS events_processed
```

## Why EKS here

Consumer is the scaling target. Producer and enrichment are stable stateless services on ECS Fargate, while Consumer needs Pod-level scaling/HPA demonstration in W4.

## Apply infrastructure

```bash
export AWS_PROFILE=leejx2
export AWS_REGION=ap-northeast-2

./scripts/tf.sh apply
```

EKS can take 10-20 minutes to create.

## Push images after destroy/apply

If you ran `terraform destroy`, ECR repositories are recreated empty. Push images again:

```bash
export IMAGE_TAG=dev-latest
./scripts/ecr-build-push.sh
```

## Deploy consumer to EKS

Set DB password to the same value used in `infra/terraform/terraform.tfvars`.

```bash
export DB_PASSWORD='<db_password_from_terraform.tfvars>'
export IMAGE_TAG=dev-latest
./scripts/eks-consumer-up.sh
```

## Smoke test

```bash
./scripts/aws-e2e-smoke.sh
```

Expected:

```txt
/actuator/health -> 200 UP
/v1/events -> success response
kubectl logs deployment/event-pipeline-consumer -> enriched/persisted event logs
```

## Teardown

Delete Kubernetes namespace first, then destroy AWS infrastructure.

```bash
./scripts/eks-consumer-down.sh
./scripts/aws-dev-down.sh
```

## Cost note

EKS control plane is not free. Do not leave it running overnight during side-project work.
