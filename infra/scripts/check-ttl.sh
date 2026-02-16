#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TF_DIR="${REPO_ROOT}/infra/terraform"
ENV_FILE="${REPO_ROOT}/infra/.env"

# Source .env if present (fallback to environment variables)
if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
  set +a
fi

COST_PER_HOUR_EUR="0.0296"
DEFAULT_TTL_HOURS=4
MODE="warn"

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--warn|--status]

  --warn    Print TTL warning only when threshold is exceeded (default)
  --status  Print current cluster runtime and estimated cost
USAGE
}

for arg in "$@"; do
  case "${arg}" in
    --warn)
      MODE="warn"
      ;;
    --status)
      MODE="status"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'ERROR: Unknown argument: %s\n' "${arg}" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "${DEMO_SKIP_TTL_CHECK:-0}" == "1" ]]; then
  exit 0
fi

if ! command -v terraform >/dev/null 2>&1; then
  if [[ "${MODE}" == "status" ]]; then
    printf 'Terraform is not installed; cannot determine cluster status.\n'
  fi
  exit 0
fi

cluster_exists() {
  local resources
  resources="$(terraform -chdir="${TF_DIR}" state list 2>/dev/null || true)"
  [[ -n "${resources}" ]]
}

terraform_output_raw() {
  local name="$1"
  terraform -chdir="${TF_DIR}" output -raw "${name}" 2>/dev/null || true
}

to_epoch() {
  local iso_timestamp="$1"
  python3 - "${iso_timestamp}" <<'PY'
from datetime import datetime
import sys

value = sys.argv[1]
try:
    dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
    print(int(dt.timestamp()))
except Exception:
    print(0)
PY
}

format_duration() {
  local seconds="$1"
  local hours
  local minutes

  hours=$((seconds / 3600))
  minutes=$(((seconds % 3600) / 60))

  if (( hours > 0 )); then
    printf '%sh %sm' "${hours}" "${minutes}"
    return 0
  fi

  printf '%sm' "${minutes}"
}

estimate_cost() {
  local seconds="$1"
  awk -v secs="${seconds}" -v rate="${COST_PER_HOUR_EUR}" 'BEGIN { printf "%.2f", (secs / 3600) * rate }'
}

read_cluster_name() {
  local name
  name="$(terraform_output_raw cluster_name)"
  if [[ -n "${name}" ]]; then
    printf '%s\n' "${name}"
    return 0
  fi

  printf 'rcd-demo\n'
}

read_created_at_from_hcloud() {
  local cluster_name="$1"
  local json

  if ! command -v hcloud >/dev/null 2>&1; then
    return 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    return 1
  fi

  if [[ -z "${HCLOUD_TOKEN:-}" ]]; then
    return 1
  fi

  if ! json="$(hcloud server list --selector "cluster=${cluster_name}" -o json 2>/dev/null)"; then
    return 1
  fi

  printf '%s\n' "${json}" | jq -r '.[0].labels.created_at // empty'
}

read_created_at() {
  local cluster_name="$1"
  local from_hcloud
  local from_terraform

  from_hcloud="$(read_created_at_from_hcloud "${cluster_name}" 2>/dev/null || true)"
  if [[ -n "${from_hcloud}" ]]; then
    printf '%s\n' "${from_hcloud}"
    return 0
  fi

  from_terraform="$(terraform_output_raw cluster_created_at)"
  printf '%s\n' "${from_terraform}"
}

read_ttl_hours() {
  local ttl

  ttl="$(terraform_output_raw ttl_hours)"
  if [[ "${ttl}" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "${ttl}"
    return 0
  fi

  printf '%s\n' "${DEFAULT_TTL_HOURS}"
}

if ! cluster_exists; then
  if [[ "${MODE}" == "status" ]]; then
    printf 'No cloud demo cluster is currently tracked in Terraform state.\n'
  fi
  exit 0
fi

cluster_name="$(read_cluster_name)"
created_at="$(read_created_at "${cluster_name}")"
ttl_hours="$(read_ttl_hours)"

if [[ -z "${created_at}" ]]; then
  if [[ "${MODE}" == "status" ]]; then
    printf 'Cloud cluster is running, but created_at metadata is unavailable.\n'
  fi
  exit 0
fi

created_epoch="$(to_epoch "${created_at}")"
if [[ "${created_epoch}" == "0" ]]; then
  if [[ "${MODE}" == "status" ]]; then
    printf 'Unable to parse created_at timestamp: %s\n' "${created_at}"
  fi
  exit 0
fi

now_epoch="$(date +%s)"
elapsed_seconds="$((now_epoch - created_epoch))"
if (( elapsed_seconds < 0 )); then
  elapsed_seconds=0
fi

ttl_seconds="$((ttl_hours * 3600))"
elapsed_readable="$(format_duration "${elapsed_seconds}")"
estimated_cost="$(estimate_cost "${elapsed_seconds}")"

if [[ "${MODE}" == "status" ]]; then
  printf 'Cluster: %s\n' "${cluster_name}"
  printf 'Age: %s\n' "${elapsed_readable}"
  printf 'Estimated cost: EUR %s\n' "${estimated_cost}"
  printf 'TTL threshold: %sh\n' "${ttl_hours}"

  if (( elapsed_seconds > ttl_seconds )); then
    printf 'TTL status: exceeded\n'
  else
    printf 'TTL status: within threshold\n'
  fi
  exit 0
fi

if (( elapsed_seconds > ttl_seconds )); then
  printf 'WARNING: Demo cluster has been running for %s (TTL: %sh)\n' "${elapsed_readable}" "${ttl_hours}" >&2
  printf 'Estimated cost so far: EUR %s\n' "${estimated_cost}" >&2
  printf "Run 'make demo-cloud-down' when finished to stop billing.\n" >&2
fi
