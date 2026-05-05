# W3-2 — ECR Image Publishing

## Goal

Build and push Docker images for:

- producer
- consumer
- enrichment

Images are pushed to the ECR repositories created by `infra/terraform`.

## Prerequisites

```bash
aws sts get-caller-identity
terraform -chdir=infra/terraform output
```

Confirm the AWS account is the personal account before pushing.

## Local build smoke test

```bash
./scripts/docker-build-local.sh
```

This builds local images:

```txt
event-pipeline-demo/producer:local
event-pipeline-demo/consumer:local
event-pipeline-demo/enrichment:local
```

## Push to ECR

```bash
export AWS_PROFILE=event-pipeline-personal
export AWS_REGION=ap-northeast-2
export IMAGE_TAG=$(git rev-parse --short HEAD)

./scripts/ecr-build-push.sh
```

The script also tags each image as:

```txt
<git-sha>
dev-latest
```

## Notes

- Docker build context is the repository root because each service depends on the shared `proto` module and Gradle root files.
- Runtime images use JRE only.
- Build stage uses JDK 21 and Gradle wrapper.
- Images are built for `linux/amd64` by default because ECS/EKS nodes are commonly amd64 unless changed later.

## Cost

Pushing ECR images has negligible cost at this stage, but the RDS/Redis resources created by Terraform keep billing while running.
