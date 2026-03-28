#!/usr/bin/env bash
# ============================================================
# localstack-init.sh
#
# Creates the S3 buckets needed for Terraform remote state
# before running terraform init. LocalStack must be running.
# ============================================================

set -euo pipefail

ENDPOINT="http://localhost:4566"
AWS_OPTS="--endpoint-url=${ENDPOINT} --region us-east-1 --no-cli-pager"

export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

wait_for_localstack() {
  log_info "Waiting for LocalStack to be ready..."
  local max_attempts=30
  local attempt=0

  until aws ${AWS_OPTS} s3 ls &>/dev/null; do
    attempt=$((attempt + 1))
    if [[ $attempt -ge $max_attempts ]]; then
      log_error "LocalStack did not become ready after ${max_attempts} attempts."
      log_error "Start LocalStack with: docker compose up -d localstack"
      exit 1
    fi
    echo "  Attempt ${attempt}/${max_attempts} — waiting 2s..."
    sleep 2
  done

  log_success "LocalStack is ready."
}

create_state_bucket() {
  local bucket="$1"
  if aws ${AWS_OPTS} s3 ls "s3://${bucket}" &>/dev/null; then
    log_info "Bucket already exists: s3://${bucket}"
  else
    aws ${AWS_OPTS} s3 mb "s3://${bucket}"
    # Enable versioning for state bucket safety
    aws ${AWS_OPTS} s3api put-bucket-versioning \
      --bucket "${bucket}" \
      --versioning-configuration Status=Enabled
    log_success "Created state bucket: s3://${bucket} (versioning enabled)"
  fi
}

list_resources() {
  log_info "Current S3 buckets in LocalStack:"
  aws ${AWS_OPTS} s3 ls

  log_info "Current IAM roles in LocalStack:"
  aws ${AWS_OPTS} iam list-roles --query 'Roles[*].RoleName' --output table 2>/dev/null || true
}

main() {
  echo ""
  echo "============================================================"
  echo "  LocalStack — Terraform State Bootstrap"
  echo "============================================================"
  echo ""

  wait_for_localstack
  create_state_bucket "terraform-state-dev"
  create_state_bucket "terraform-state-staging"
  create_state_bucket "terraform-state-prod"
  list_resources

  echo ""
  log_success "LocalStack state buckets ready."
  echo ""
  echo "Next step:"
  echo "  cd environments/dev && terraform init && terraform plan"
  echo ""
}

main "$@"
