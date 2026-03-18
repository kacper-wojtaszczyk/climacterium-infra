#!/bin/bash
set -euo pipefail

TERRAFORM_DIR="$(dirname "$0")/../terraform"

cd "$TERRAFORM_DIR"

echo "Reading Terraform outputs..."

# PostgreSQL
PG_HOST=$(terraform output -raw postgres_host)
PG_PORT=$(terraform output -raw postgres_port)
PG_USER=$(terraform output -raw postgres_user)
PG_PASSWORD=$(terraform output -raw postgres_password)
PG_DSN=$(terraform output -raw postgres_connection_string)

echo "→ Syncing postgres-credentials..."
kubectl create secret generic postgres-credentials \
  --from-literal=host="$PG_HOST" \
  --from-literal=port="$PG_PORT" \
  --from-literal=user="$PG_USER" \
  --from-literal=password="$PG_PASSWORD" \
  --from-literal=database="postgres" \
  --from-literal=dsn="$PG_DSN" \
  --save-config \
  --dry-run=client -o yaml | kubectl apply -f -

# S3
S3_ACCESS_KEY=$(terraform output -raw s3_access_key)
S3_SECRET_KEY=$(terraform output -raw s3_secret_key)
S3_BUCKET=$(terraform output -raw s3_bucket_name)
S3_ENDPOINT=$(terraform output -raw s3_endpoint)

echo "→ Syncing s3-credentials..."
kubectl create secret generic s3-credentials \
  --from-literal=access-key="$S3_ACCESS_KEY" \
  --from-literal=secret-key="$S3_SECRET_KEY" \
  --from-literal=bucket="$S3_BUCKET" \
  --from-literal=endpoint="$S3_ENDPOINT" \
  --from-literal=region="nl-ams" \
  --save-config \
  --dry-run=client -o yaml | kubectl apply -f -

# ClickHouse — self-hosted in a pod, but password managed via Terraform variable
CH_PASSWORD=$(terraform output -raw clickhouse_password)

echo "→ Syncing clickhouse-credentials..."
kubectl create secret generic clickhouse-credentials \
  --from-literal=host="clickhouse.default.svc.cluster.local" \
  --from-literal=port="9000" \
  --from-literal=user="jackfruit" \
  --from-literal=password="$CH_PASSWORD" \
  --from-literal=database="jackfruit" \
  --save-config \
  --dry-run=client -o yaml | kubectl apply -f -

# External API keys
ADS_API_KEY=$(terraform output -raw ads_api_key)

echo "→ Syncing external-api-keys..."
kubectl create secret generic external-api-keys \
  --from-literal=ads-api-key="$ADS_API_KEY" \
  --save-config \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Done. All secrets synced."
