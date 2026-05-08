#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$ROOT_DIR/infra/terraform"
DB_USER="${DB_USER:-pipeline}"
DB_NAME="${DB_NAME:-pipeline}"
DB_PASSWORD="${DB_PASSWORD:-}"

if [ -z "$DB_PASSWORD" ]; then
  echo "ERROR: DB_PASSWORD is required" >&2
  exit 1
fi

RDS_ENDPOINT="$(cd "$TF_DIR" && terraform output -raw rds_endpoint)"

psql "postgresql://${DB_USER}:${DB_PASSWORD}@${RDS_ENDPOINT}:5432/${DB_NAME}?sslmode=require" \
  -c "select count(*) as events_processed_count from events_processed;" \
  -c "select enrichment_cache_hit, count(*) from events_processed group by enrichment_cache_hit order by enrichment_cache_hit;" \
  -c "select user_id, event_type, enrichment_country, enrichment_tier, enrichment_cache_hit, processed_at from events_processed order by processed_at desc limit 10;"
