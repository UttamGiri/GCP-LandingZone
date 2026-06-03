#!/usr/bin/env bash
# Bootstrap script — deploy GCP Landing Zone stages in order (LZA-style)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="${ROOT_DIR}/configs"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()   { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] STAGE

Stages:
  0-org-setup       Organization, folders, platform projects, IAM
  1-security        Org policies, KMS, logging sinks
  2-networking      Shared VPC, egress NAT, DNS, firewall
  3-project-factory Workload projects (account vending)
  4-cicd            Workload Identity, Cloud Build triggers
  all               Deploy all stages sequentially

Options:
  -p, --plan-only   Run terraform plan only (no apply)
  -h, --help        Show this help

Prerequisites:
  - gcloud CLI authenticated with org admin
  - terraform >= 1.5
  - Bootstrap project created manually (proj-bootstrap)
  - configs/global-config.yaml updated with org ID and billing account

Example:
  $(basename "$0") 0-org-setup
  $(basename "$0") --plan-only all
EOF
}

PLAN_ONLY=false
STAGE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--plan-only) PLAN_ONLY=true; shift ;;
    -h|--help)      usage; exit 0 ;;
    *)              STAGE="$1"; shift ;;
  esac
done

if [[ -z "$STAGE" ]]; then
  error "Stage argument required"
  usage
  exit 1
fi

check_prerequisites() {
  log "Checking prerequisites..."

  command -v terraform >/dev/null 2>&1 || { error "terraform not found"; exit 1; }
  command -v gcloud >/dev/null 2>&1 || { error "gcloud not found"; exit 1; }

  if [[ ! -f "${CONFIG_DIR}/global-config.yaml" ]]; then
    error "Missing ${CONFIG_DIR}/global-config.yaml"
    exit 1
  fi

  ORG_ID=$(grep -A1 "^organization:" "${CONFIG_DIR}/global-config.yaml" | grep "id:" | awk '{print $2}' | tr -d '"')
  if [[ "$ORG_ID" == "000000000000" ]]; then
    warn "Update configs/global-config.yaml with your real organization ID"
  fi

  log "Prerequisites OK"
}

deploy_stage() {
  local stage=$1
  local stage_dir="${ROOT_DIR}/stages/${stage}"

  if [[ ! -d "$stage_dir" ]]; then
    error "Stage directory not found: $stage_dir"
    exit 1
  fi

  log "=========================================="
  log "Deploying stage: ${stage}"
  log "=========================================="

  cd "$stage_dir"

  terraform init -input=false

  if [[ "$PLAN_ONLY" == true ]]; then
    terraform plan -input=false
  else
    terraform plan -input=false -out=tfplan
    terraform apply -input=false tfplan
    rm -f tfplan
  fi

  log "Stage ${stage} complete"
}

deploy_all() {
  local stages=(
    "0-org-setup"
    "1-security"
    "2-networking"
    "3-project-factory"
    "4-cicd"
  )

  for stage in "${stages[@]}"; do
    deploy_stage "$stage"
  done

  log "All stages deployed successfully"
}

main() {
  check_prerequisites

  if [[ "$STAGE" == "all" ]]; then
    deploy_all
  else
    deploy_stage "$STAGE"
  fi
}

main
