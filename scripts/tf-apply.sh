#!/usr/bin/env bash
# ============================================================
# tf-apply.sh — Wrapper for terraform plan/apply/destroy
# with environment validation, auto-approval gate for prod,
# and plan artifact saving.
#
# Usage:
#   ./scripts/tf-apply.sh dev plan
#   ./scripts/tf-apply.sh dev apply
#   ./scripts/tf-apply.sh prod plan
#   ./scripts/tf-apply.sh prod apply    # requires CONFIRM_PROD=yes
#   ./scripts/tf-apply.sh dev destroy
# ============================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

ENVIRONMENT="${1:-}"
ACTION="${2:-plan}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

VALID_ENVIRONMENTS=("dev" "staging" "prod")
VALID_ACTIONS=("plan" "apply" "destroy" "init" "output")

# ---- Validate inputs ----
if [[ -z "${ENVIRONMENT}" ]]; then
  log_error "Usage: $0 <environment> <action>"
  log_error "  environment: ${VALID_ENVIRONMENTS[*]}"
  log_error "  action:      ${VALID_ACTIONS[*]}"
  exit 1
fi

if [[ ! " ${VALID_ENVIRONMENTS[*]} " =~ " ${ENVIRONMENT} " ]]; then
  log_error "Invalid environment: ${ENVIRONMENT}. Must be one of: ${VALID_ENVIRONMENTS[*]}"
  exit 1
fi

if [[ ! " ${VALID_ACTIONS[*]} " =~ " ${ACTION} " ]]; then
  log_error "Invalid action: ${ACTION}. Must be one of: ${VALID_ACTIONS[*]}"
  exit 1
fi

ENV_DIR="${REPO_ROOT}/environments/${ENVIRONMENT}"
if [[ ! -d "${ENV_DIR}" ]]; then
  log_error "Environment directory not found: ${ENV_DIR}"
  exit 1
fi

# ---- Production safety gate ----
if [[ "${ENVIRONMENT}" == "prod" && "${ACTION}" == "apply" ]]; then
  if [[ "${CONFIRM_PROD:-}" != "yes" ]]; then
    log_warn "Production apply requires explicit confirmation."
    log_warn "Set CONFIRM_PROD=yes to proceed."
    log_warn "  CONFIRM_PROD=yes ./scripts/tf-apply.sh prod apply"
    exit 1
  fi
fi

if [[ "${ENVIRONMENT}" == "prod" && "${ACTION}" == "destroy" ]]; then
  log_error "Destroying production is not allowed via this script."
  log_error "If this is genuinely required, run terraform destroy manually from environments/prod/"
  exit 1
fi

# ---- LocalStack credentials ----
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export TF_CLI_ARGS_plan="-compact-warnings"

PLAN_FILE="${ENV_DIR}/tfplan-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S).tfplan"

log_info "Environment : ${ENVIRONMENT}"
log_info "Action      : ${ACTION}"
log_info "Directory   : ${ENV_DIR}"

cd "${ENV_DIR}"

case "${ACTION}" in
  init)
    log_info "Running terraform init..."
    terraform init -upgrade
    log_success "Init complete."
    ;;
  plan)
    log_info "Running terraform plan..."
    terraform plan -out="${PLAN_FILE}" -var-file="terraform.tfvars" 2>/dev/null || \
    terraform plan -out="${PLAN_FILE}"
    log_success "Plan saved to: ${PLAN_FILE}"
    ;;
  apply)
    # Check if a saved plan exists for this environment
    LATEST_PLAN=$(ls -t tfplan-${ENVIRONMENT}-*.tfplan 2>/dev/null | head -1 || true)
    if [[ -n "${LATEST_PLAN}" ]]; then
      log_info "Applying saved plan: ${LATEST_PLAN}"
      terraform apply "${LATEST_PLAN}"
    else
      log_warn "No saved plan found. Running plan+apply together."
      terraform apply -auto-approve
    fi
    log_success "Apply complete."
    ;;
  destroy)
    log_warn "Destroying ${ENVIRONMENT} environment..."
    terraform destroy -auto-approve
    log_success "Destroy complete."
    ;;
  output)
    terraform output -json
    ;;
esac
