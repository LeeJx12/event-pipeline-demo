# W3 AWS Daily Routine

## 핵심 룰

`terraform destroy`를 하면 ECR repository도 삭제된다.  
따라서 다음날 `terraform apply`를 다시 하면 ECR repository는 비어 있다.

즉, 매번 fresh apply 이후에는 반드시 이미지를 다시 push해야 한다.

```txt
terraform apply
→ ECR repo 생성
→ Docker image 3개 push
→ ECS force-new-deployment
→ ALB health check
```

## 시작 루틴

```bash
export AWS_PROFILE=leejx2
export AWS_REGION=ap-northeast-2

./scripts/aws-dev-up.sh
```

이 스크립트가 하는 일:

```txt
1. AWS account ID 확인
2. terraform init/apply
3. producer/consumer/enrichment image build + ECR push
4. producer/enrichment ECS force-new-deployment
5. ECS service running count 확인
6. producer ALB /actuator/health 확인
```

## 종료 루틴

```bash
export AWS_PROFILE=leejx2
export AWS_REGION=ap-northeast-2

./scripts/aws-dev-down.sh
```

이 스크립트가 하는 일:

```txt
1. AWS account ID 확인
2. terraform output 백업
3. terraform destroy
4. 다음 apply 때 ECR image 재push 필요하다는 알림
```

## 성공 기준

```txt
producer running=1
enrichment running=1
GET /actuator/health → 200 OK {"status":"UP"}
```

## 자주 나는 문제

### CannotPullContainerError: image not found

원인:

```txt
terraform destroy 후 다시 apply해서 ECR repo가 새로 만들어졌는데, image를 아직 push하지 않음.
```

해결:

```bash
./scripts/ecr-build-push.sh

aws ecs update-service \
  --cluster event-pipeline-demo-dev-cluster \
  --service event-pipeline-demo-dev-producer \
  --force-new-deployment \
  --profile leejx2 \
  --region ap-northeast-2
```

### ALB 503

원인:

```txt
ALB target group에 healthy producer task가 없음.
```

먼저 ECS running count 확인:

```bash
aws ecs describe-services \
  --cluster event-pipeline-demo-dev-cluster \
  --services event-pipeline-demo-dev-producer event-pipeline-demo-dev-enrichment \
  --query 'services[].{name:serviceName,running:runningCount,desired:desiredCount,status:status}' \
  --output table \
  --profile leejx2 \
  --region ap-northeast-2
```

`running=0`이면 ALB 문제가 아니라 ECS task 문제다.
