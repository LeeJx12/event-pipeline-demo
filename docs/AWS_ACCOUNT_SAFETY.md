# AWS Account Safety

## 목적

회사 AWS 계정에 실수로 Terraform apply/destroy를 치는 사고를 막는다.

## 안전 실행

직접 Terraform을 치지 말고 wrapper를 쓴다.

```bash
./scripts/tf.sh plan
./scripts/tf.sh apply
./scripts/tf.sh destroy
```

계정 ID가 다르면 실행 전에 실패한다.

## 기본값

```txt
expected account id: 821465445446
profile: leejx2
region: ap-northeast-2
```

override가 필요하면:

```bash
EXPECTED_AWS_ACCOUNT_ID=821465445446 AWS_PROFILE=leejx2 ./scripts/tf.sh plan
```
