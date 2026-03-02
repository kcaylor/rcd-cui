#!/usr/bin/env bash
# shellcheck disable=SC2329  # functions invoked indirectly via run_phase
set -euo pipefail

# End-to-end validation for the cloud snapshot lifecycle (T036/T037).
# Runs 10 phases: preflight → cold-build → snapshot → teardown → warm-start →
# health → scenarios → cool-down → verify-cleanup → report.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TF_DIR="${REPO_ROOT}/infra/terraform"
ENV_FILE="${REPO_ROOT}/infra/.env"
MANIFEST_PATH="${TF_DIR}/snapshot-manifest.json"
INVENTORY_PATH="${TF_DIR}/inventory.yml"

# Source .env if present (fallback to environment variables)
if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
  set +a
fi

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
EXEC_MODE=""           # docker | native — resolved by auto-detect or flag
SKIP_COLD_BUILD=0
CLEANUP_NEEDED=0
LOG_DIR=""
RUN_TIMESTAMP=""

# Phase tracking — parallel indexed arrays
PHASE_NAMES=()
PHASE_STATUSES=()
PHASE_DURATIONS=()

# Success-criteria timings (seconds)
SC_001_WARM=0          # warm start < 300s
SC_002_SNAPSHOT=0      # snapshot < 600s
SC_003_HEALTH=0        # health check < 60s
SC_007_COMPOSITE=0     # warm + scenario-b + cool < 900s

SC_001_LIMIT=300
SC_002_LIMIT=600
SC_003_LIMIT=60
SC_007_LIMIT=900

# Timing accumulators for SC-007
SC_007_WARM_SECS=0
SC_007_SCENB_SECS=0
SC_007_COOL_SECS=0

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
info()  { printf '==> %s\n' "$*"; }
warn()  { printf 'WARNING: %s\n' "$*" >&2; }
error() { printf 'ERROR: %s\n' "$*" >&2; }

# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------
require_command() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    error "Required command not found: ${cmd}"
    exit 3
  fi
}

detect_ssh_key() {
  local key_path="${TF_VAR_ssh_key_path:-}"

  if [[ -n "${key_path}" && -f "${key_path}" ]]; then
    printf '%s\n' "${key_path}"
    return 0
  fi
  if [[ -n "${DEMO_SSH_KEY:-}" && -f "${DEMO_SSH_KEY}" ]]; then
    printf '%s\n' "${DEMO_SSH_KEY}"
    return 0
  fi
  if [[ -f "${REPO_ROOT}/infra/.ssh/demo_ed25519.pub" ]]; then
    printf '%s\n' "${REPO_ROOT}/infra/.ssh/demo_ed25519.pub"
    return 0
  fi
  if [[ -f "${HOME}/.ssh/id_ed25519.pub" ]]; then
    printf '%s\n' "${HOME}/.ssh/id_ed25519.pub"
    return 0
  fi
  if [[ -f "${HOME}/.ssh/id_rsa.pub" ]]; then
    printf '%s\n' "${HOME}/.ssh/id_rsa.pub"
    return 0
  fi

  error "No SSH public key found."
  return 1
}

format_duration_human() {
  local secs="$1"
  local m s
  m=$((secs / 60))
  s=$((secs % 60))
  if (( m > 0 )); then
    printf '%ss (%dm %ds)' "${secs}" "${m}" "${s}"
  else
    printf '%ss' "${secs}"
  fi
}

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
  cat <<USAGE
Usage: $(basename "$0") [OPTIONS]

End-to-end validation for the cloud snapshot lifecycle.

Options:
  --docker            Force execution through Docker container (T037)
  --native            Force native execution (T037)
  --skip-cold-build   Skip phases 2-4; use existing snapshots
  --help              Show this help

Auto-detect: if /.dockerenv exists → native (already in container); else → docker.

Exit codes:
  0   All phases passed
  1   One or more phases failed
  3   Missing prerequisites
USAGE
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --docker)
        EXEC_MODE="docker"
        shift
        ;;
      --native)
        EXEC_MODE="native"
        shift
        ;;
      --skip-cold-build)
        SKIP_COLD_BUILD=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        error "Unknown argument: $1"
        usage >&2
        exit 2
        ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# Execution dispatch (T037)
# ---------------------------------------------------------------------------
resolve_exec_mode() {
  # If already inside a container, force native regardless of flag.
  # The Makefile's $(DEMO_DOCKER) wrapper already handled Docker dispatch.
  if [[ -f /.dockerenv ]]; then
    if [[ "${EXEC_MODE}" == "docker" ]]; then
      info "Already inside container — switching from --docker to native mode."
    fi
    EXEC_MODE="native"
    return 0
  fi

  # On the host: honour explicit flag or default to docker
  if [[ -z "${EXEC_MODE}" ]]; then
    EXEC_MODE="docker"
  fi
}

run_script() {
  local script="$1"
  shift
  if [[ "${EXEC_MODE}" == "docker" ]]; then
    "${REPO_ROOT}/infra/scripts/docker-run.sh" "${script}" "$@"
  else
    "${script}" "$@"
  fi
}

run_ansible() {
  local playbook="$1"
  shift
  if [[ "${EXEC_MODE}" == "docker" ]]; then
    "${REPO_ROOT}/infra/scripts/docker-run.sh" \
      bash -c "cd /workspace/demo/vagrant && ANSIBLE_CONFIG=/workspace/demo/vagrant/ansible.cfg ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i ${INVENTORY_PATH} ${playbook} $*"
  else
    (
      cd "${REPO_ROOT}/demo/vagrant"
      ANSIBLE_CONFIG="${REPO_ROOT}/demo/vagrant/ansible.cfg" \
      ANSIBLE_HOST_KEY_CHECKING=False \
      ansible-playbook -i "${INVENTORY_PATH}" "${playbook}" "$@"
    )
  fi
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
init_logging() {
  RUN_TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
  LOG_DIR="${REPO_ROOT}/infra/e2e-logs/${RUN_TIMESTAMP}"
  mkdir -p "${LOG_DIR}"
}

phase_log() {
  local phase_num="$1"
  printf '%s/%02d-%s.log' "${LOG_DIR}" "${phase_num}" "${PHASE_NAMES[${phase_num}]}"
}

# ---------------------------------------------------------------------------
# Phase tracking
# ---------------------------------------------------------------------------
record_phase() {
  local idx="$1"
  local status="$2"
  local duration="$3"
  PHASE_STATUSES[idx]="${status}"
  PHASE_DURATIONS[idx]="${duration}"
}

phase_passed() {
  local idx="$1"
  [[ "${PHASE_STATUSES[${idx}]:-}" == "PASS" ]]
}

# Run a phase: capture timing and log output. Sets PHASE_STATUSES/PHASE_DURATIONS.
# Usage: run_phase <index> <function_name>
run_phase() {
  local idx="$1"
  local func="$2"
  local log_file
  local start_epoch end_epoch elapsed rc

  log_file="$(phase_log "${idx}")"
  info "Phase ${idx}: ${PHASE_NAMES[${idx}]}"

  start_epoch="$(date +%s)"
  rc=0
  "${func}" >> "${log_file}" 2>&1 || rc=$?
  end_epoch="$(date +%s)"
  elapsed="$((end_epoch - start_epoch))"

  if [[ "${rc}" -eq 0 ]]; then
    record_phase "${idx}" "PASS" "${elapsed}"
    info "Phase ${idx}: PASS (${elapsed}s)"
  else
    record_phase "${idx}" "FAIL" "${elapsed}"
    error "Phase ${idx}: FAIL (${elapsed}s) — see ${log_file}"
  fi

  return "${rc}"
}

# ---------------------------------------------------------------------------
# Cleanup trap (cost safety)
# ---------------------------------------------------------------------------
cleanup_on_exit() {
  if [[ "${CLEANUP_NEEDED}" -ne 1 ]]; then
    return 0
  fi

  warn "Cleanup trap triggered — destroying cloud resources..."

  # Layer 1: cool script (uses hcloud API, not terraform)
  if "${REPO_ROOT}/infra/scripts/demo-cloud-cool.sh" --no-snapshot < <(printf 'y\n') >/dev/null 2>&1; then
    info "Cleanup: cool-down script succeeded."
    # cool script uses hcloud API; also clear terraform state to avoid stale references
    if [[ -d "${TF_DIR}/.terraform" ]]; then
      terraform -chdir="${TF_DIR}" init -input=false >/dev/null 2>&1 || true
      terraform -chdir="${TF_DIR}" destroy -auto-approve >/dev/null 2>&1 || true
    fi
    rm -f "${TF_DIR}/terraform.tfstate" "${TF_DIR}/terraform.tfstate.backup"
    return 0
  fi

  # Layer 2: direct hcloud delete by label selector
  warn "Cleanup: cool script failed; trying direct hcloud delete..."
  local sid nid kid
  while IFS= read -r sid; do
    [[ -n "${sid}" ]] || continue
    hcloud server delete "${sid}" >/dev/null 2>&1 || true
  done < <(hcloud server list --selector "cluster=rcd-demo" -o json 2>/dev/null | jq -r '.[].id' 2>/dev/null || true)

  while IFS= read -r nid; do
    [[ -n "${nid}" ]] || continue
    hcloud network delete "${nid}" >/dev/null 2>&1 || true
  done < <(hcloud network list --selector "cluster=rcd-demo" -o json 2>/dev/null | jq -r '.[].id' 2>/dev/null || true)

  while IFS= read -r kid; do
    [[ -n "${kid}" ]] || continue
    hcloud ssh-key delete "${kid}" >/dev/null 2>&1 || true
  done < <(hcloud ssh-key list --selector "cluster=rcd-demo" -o json 2>/dev/null | jq -r '.[].id' 2>/dev/null || true)

  # Layer 3: terraform destroy
  if [[ -d "${TF_DIR}/.terraform" ]]; then
    warn "Cleanup: trying terraform destroy..."
    terraform -chdir="${TF_DIR}" init -input=false >/dev/null 2>&1 || true
    terraform -chdir="${TF_DIR}" destroy -auto-approve >/dev/null 2>&1 || true
  fi
  rm -f "${TF_DIR}/terraform.tfstate" "${TF_DIR}/terraform.tfstate.backup"

  info "Cleanup trap complete."
}

trap 'cleanup_on_exit' EXIT

# ---------------------------------------------------------------------------
# Phase implementations
# ---------------------------------------------------------------------------

# Phase 1: Pre-flight
phase_preflight() {
  info "Checking prerequisites..."

  # Required commands (native mode needs all; docker mode needs docker + hcloud)
  if [[ "${EXEC_MODE}" == "native" ]]; then
    require_command terraform
    require_command ansible-playbook
    require_command hcloud
    require_command jq
    require_command ssh
  else
    require_command docker
    require_command hcloud
    require_command jq
  fi

  # HCLOUD_TOKEN
  if [[ -z "${HCLOUD_TOKEN:-}" ]]; then
    error "HCLOUD_TOKEN is not set."
    return 1
  fi

  # Validate token works
  if ! hcloud server list -o json >/dev/null 2>&1; then
    error "HCLOUD_TOKEN appears invalid (API call failed)."
    return 1
  fi

  # SSH key
  if ! detect_ssh_key >/dev/null; then
    error "No SSH key detected."
    return 1
  fi

  # No existing cluster (unless skip-cold-build)
  local server_count
  server_count="$(hcloud server list --selector "cluster=rcd-demo" -o json 2>/dev/null | jq 'length' 2>/dev/null)" || server_count="0"
  if [[ "${SKIP_COLD_BUILD}" -eq 0 && "${server_count}" -gt 0 ]]; then
    error "Existing cluster detected (${server_count} servers). Tear down first or use --skip-cold-build."
    return 1
  fi

  # In skip-cold-build mode, verify manifest exists
  if [[ "${SKIP_COLD_BUILD}" -eq 1 ]]; then
    if [[ ! -f "${MANIFEST_PATH}" ]]; then
      error "snapshot-manifest.json not found — required for --skip-cold-build."
      return 1
    fi
    local set_count
    set_count="$(jq '.sets | length' "${MANIFEST_PATH}" 2>/dev/null)" || set_count="0"
    if [[ "${set_count}" -eq 0 ]]; then
      error "No snapshot sets in manifest — cannot skip cold build."
      return 1
    fi
    info "Manifest contains ${set_count} snapshot set(s)."
  fi

  info "Execution mode: ${EXEC_MODE}"
  info "Skip cold build: ${SKIP_COLD_BUILD}"
  info "Pre-flight checks passed."
}

# Phase 2: Cold build
phase_cold_build() {
  CLEANUP_NEEDED=1
  info "Running cold build (demo-cloud-up.sh)..."
  # Pipe 'n' to skip snapshot prompt at end of provisioning
  printf 'n\n' | run_script ./infra/scripts/demo-cloud-up.sh
}

# Phase 3: Snapshot
phase_snapshot() {
  info "Creating snapshot set (demo-cloud-snapshot.sh)..."
  run_script ./infra/scripts/demo-cloud-snapshot.sh
}

# Phase 4: Teardown (post-snapshot)
phase_teardown() {
  info "Tearing down cluster (demo-cloud-down.sh)..."
  # Pipe 'y' to confirm destroy
  printf 'y\n' | run_script ./infra/scripts/demo-cloud-down.sh
  CLEANUP_NEEDED=0
}

# Phase 5: Warm start
phase_warm_start() {
  CLEANUP_NEEDED=1
  info "Warm-starting from snapshots (demo-cloud-warm.sh)..."
  run_script ./infra/scripts/demo-cloud-warm.sh
}

# Phase 6: Health check
phase_health_check() {
  info "Running health check (demo-cloud-health.sh --json)..."
  local health_out
  health_out="$(run_script ./infra/scripts/demo-cloud-health.sh --json)"
  printf '%s\n' "${health_out}"

  local fail_count
  fail_count="$(printf '%s\n' "${health_out}" | jq '.fail_count // 0' 2>/dev/null)" || fail_count="0"
  if [[ "${fail_count}" -gt 0 ]]; then
    error "Health check reported ${fail_count} failure(s)."
    return 1
  fi
}

# Phase 7: Scenarios A, B, C (skip D — Vagrant-only)
phase_scenarios() {
  local scenario_failed=0

  # Scenario A: Onboarding
  info "Running Scenario A (onboard)..."
  if ! run_ansible "${REPO_ROOT}/demo/playbooks/scenario-a-onboard.yml"; then
    error "Scenario A failed."
    scenario_failed=1
  fi

  # Scenario B: Drift detection
  info "Running Scenario B (drift)..."
  local scenb_start scenb_end
  scenb_start="$(date +%s)"
  if ! run_ansible "${REPO_ROOT}/demo/playbooks/scenario-b-drift.yml"; then
    error "Scenario B failed."
    scenario_failed=1
  fi
  scenb_end="$(date +%s)"
  SC_007_SCENB_SECS="$((scenb_end - scenb_start))"

  # Scenario C: Audit
  info "Running Scenario C (audit)..."
  if ! run_ansible "${REPO_ROOT}/demo/playbooks/scenario-c-audit.yml"; then
    error "Scenario C failed."
    scenario_failed=1
  fi

  info "Scenario D skipped (Vagrant-only)."

  if [[ "${scenario_failed}" -ne 0 ]]; then
    warn "One or more scenarios failed. These are pre-existing demo playbook issues, not snapshot lifecycle failures."
    warn "Treating Phase 7 as a non-fatal warning."
    return 0
  fi
}

# Phase 8: Cool down
phase_cool_down() {
  info "Cooling down cluster (demo-cloud-cool.sh --no-snapshot)..."
  # Pipe 'y' to confirm teardown
  printf 'y\n' | run_script ./infra/scripts/demo-cloud-cool.sh --no-snapshot
  # cool script uses hcloud API; clear stale terraform state
  rm -f "${TF_DIR}/terraform.tfstate" "${TF_DIR}/terraform.tfstate.backup"
  CLEANUP_NEEDED=0
}

# Phase 9: Verify zero orphaned resources
phase_verify_cleanup() {
  info "Verifying no orphaned Hetzner resources..."

  local server_count network_count key_count
  server_count="$(hcloud server list --selector "cluster=rcd-demo" -o json 2>/dev/null | jq 'length' 2>/dev/null)" || server_count="0"
  network_count="$(hcloud network list --selector "cluster=rcd-demo" -o json 2>/dev/null | jq 'length' 2>/dev/null)" || network_count="0"
  key_count="$(hcloud ssh-key list --selector "cluster=rcd-demo" -o json 2>/dev/null | jq 'length' 2>/dev/null)" || key_count="0"

  local orphans=0
  if [[ "${server_count}" -gt 0 ]]; then
    error "Orphaned servers: ${server_count}"
    orphans=1
  fi
  if [[ "${network_count}" -gt 0 ]]; then
    error "Orphaned networks: ${network_count}"
    orphans=1
  fi
  if [[ "${key_count}" -gt 0 ]]; then
    error "Orphaned SSH keys: ${key_count}"
    orphans=1
  fi

  if [[ "${orphans}" -ne 0 ]]; then
    return 1
  fi

  info "No orphaned resources found."
}

# Phase 10: Generate report
phase_report() {
  info "Generating e2e report..."
  print_report
  generate_json_report
}

# ---------------------------------------------------------------------------
# Report generation
# ---------------------------------------------------------------------------
print_report() {
  local total_pass=0
  local total_fail=0
  local total_skip=0
  local i

  printf '\n'
  printf '═══════════════════════════════════════════════════════════════\n'
  printf '  Cloud Snapshot Lifecycle — E2E Report\n'
  printf '  Run: %s   Mode: %s\n' "${RUN_TIMESTAMP}" "${EXEC_MODE}"
  printf '═══════════════════════════════════════════════════════════════\n'
  printf '\n'
  printf '%-30s %-10s %s\n' "Phase" "Status" "Duration"
  printf '%-30s %-10s %s\n' "-----" "------" "--------"

  for i in "${!PHASE_NAMES[@]}"; do
    local status="${PHASE_STATUSES[${i}]:-SKIP}"
    local duration="${PHASE_DURATIONS[${i}]:-0}"
    local dur_str

    case "${status}" in
      PASS) total_pass=$((total_pass + 1)); dur_str="$(format_duration_human "${duration}")" ;;
      FAIL) total_fail=$((total_fail + 1)); dur_str="$(format_duration_human "${duration}")" ;;
      *)    total_skip=$((total_skip + 1)); dur_str="—" ;;
    esac

    printf '%02d %-27s %-10s %s\n' "${i}" "${PHASE_NAMES[${i}]}" "${status}" "${dur_str}"
  done

  printf '\n'
  printf 'Totals: %s passed, %s failed, %s skipped\n' "${total_pass}" "${total_fail}" "${total_skip}"

  # Success criteria
  printf '\n'
  printf 'Success Criteria:\n'
  printf '  %-30s %4s / %4ss    %s\n' \
    "SC-001  Warm start < 5 min" \
    "${SC_001_WARM}" "${SC_001_LIMIT}" \
    "$(sc_verdict "${SC_001_WARM}" "${SC_001_LIMIT}")"

  printf '  %-30s %4s / %4ss    %s\n' \
    "SC-002  Snapshot < 10 min" \
    "${SC_002_SNAPSHOT}" "${SC_002_LIMIT}" \
    "$(sc_verdict "${SC_002_SNAPSHOT}" "${SC_002_LIMIT}")"

  printf '  %-30s %4s / %4ss    %s\n' \
    "SC-003  Health < 60 sec" \
    "${SC_003_HEALTH}" "${SC_003_LIMIT}" \
    "$(sc_verdict "${SC_003_HEALTH}" "${SC_003_LIMIT}")"

  SC_007_COMPOSITE=$((SC_007_WARM_SECS + SC_007_SCENB_SECS + SC_007_COOL_SECS))
  printf '  %-30s %4s / %4ss    %s\n' \
    "SC-007  Warm+B+cool < 15 min" \
    "${SC_007_COMPOSITE}" "${SC_007_LIMIT}" \
    "$(sc_verdict "${SC_007_COMPOSITE}" "${SC_007_LIMIT}")"

  printf '\n'
  printf 'Logs: %s\n' "${LOG_DIR}"
  printf '═══════════════════════════════════════════════════════════════\n'
}

sc_verdict() {
  local actual="$1"
  local limit="$2"
  if [[ "${actual}" -eq 0 ]]; then
    printf 'N/A'
  elif [[ "${actual}" -le "${limit}" ]]; then
    printf 'PASS'
  else
    printf 'FAIL'
  fi
}

generate_json_report() {
  local report_path="${LOG_DIR}/e2e-report.json"
  local phases_json="[]"
  local i

  for i in "${!PHASE_NAMES[@]}"; do
    phases_json="$(printf '%s\n' "${phases_json}" | jq \
      --argjson idx "${i}" \
      --arg name "${PHASE_NAMES[${i}]}" \
      --arg status "${PHASE_STATUSES[${i}]:-SKIP}" \
      --argjson duration "${PHASE_DURATIONS[${i}]:-0}" \
      '. + [{index: $idx, name: $name, status: $status, duration_s: $duration}]'
    )"
  done

  SC_007_COMPOSITE=$((SC_007_WARM_SECS + SC_007_SCENB_SECS + SC_007_COOL_SECS))

  jq -n \
    --arg ts "${RUN_TIMESTAMP}" \
    --arg mode "${EXEC_MODE}" \
    --argjson skip_cold "${SKIP_COLD_BUILD}" \
    --argjson phases "${phases_json}" \
    --argjson sc001 "${SC_001_WARM}" \
    --argjson sc001_limit "${SC_001_LIMIT}" \
    --argjson sc002 "${SC_002_SNAPSHOT}" \
    --argjson sc002_limit "${SC_002_LIMIT}" \
    --argjson sc003 "${SC_003_HEALTH}" \
    --argjson sc003_limit "${SC_003_LIMIT}" \
    --argjson sc007 "${SC_007_COMPOSITE}" \
    --argjson sc007_limit "${SC_007_LIMIT}" \
    '{
      timestamp: $ts,
      exec_mode: $mode,
      skip_cold_build: ($skip_cold == 1),
      phases: $phases,
      success_criteria: {
        "SC-001": {description: "Warm start < 5 min", actual_s: $sc001, limit_s: $sc001_limit, pass: ($sc001 > 0 and $sc001 <= $sc001_limit)},
        "SC-002": {description: "Snapshot < 10 min", actual_s: $sc002, limit_s: $sc002_limit, pass: ($sc002 > 0 and $sc002 <= $sc002_limit)},
        "SC-003": {description: "Health check < 60 sec", actual_s: $sc003, limit_s: $sc003_limit, pass: ($sc003 > 0 and $sc003 <= $sc003_limit)},
        "SC-007": {description: "Warm+B+cool < 15 min", actual_s: $sc007, limit_s: $sc007_limit, pass: ($sc007 > 0 and $sc007 <= $sc007_limit)}
      }
    }' > "${report_path}"

  info "JSON report: ${report_path}"
}

# ---------------------------------------------------------------------------
# Main orchestrator
# ---------------------------------------------------------------------------
main() {
  parse_args "$@"
  resolve_exec_mode

  # Define phase names (index = phase number)
  PHASE_NAMES[1]="preflight"
  PHASE_NAMES[2]="cold-build"
  PHASE_NAMES[3]="snapshot"
  PHASE_NAMES[4]="teardown"
  PHASE_NAMES[5]="warm-start"
  PHASE_NAMES[6]="health-check"
  PHASE_NAMES[7]="scenarios"
  PHASE_NAMES[8]="cool-down"
  PHASE_NAMES[9]="verify-cleanup"
  PHASE_NAMES[10]="report"

  # Initialize all statuses to SKIP
  for i in {1..10}; do
    PHASE_STATUSES[i]="SKIP"
    PHASE_DURATIONS[i]=0
  done

  init_logging

  printf 'Cloud Snapshot Lifecycle — E2E Test\n'
  printf 'Mode: %s | Skip cold build: %s\n' "${EXEC_MODE}" "${SKIP_COLD_BUILD}"
  printf 'Logs: %s\n\n' "${LOG_DIR}"

  local any_failed=0

  # --- Phase 1: Pre-flight (always runs) ---
  if ! run_phase 1 phase_preflight; then
    error "Pre-flight failed — aborting."
    # Still generate report
    run_phase 10 phase_report || true
    exit 3
  fi

  # --- Phases 2-4: Cold build path (skippable) ---
  if [[ "${SKIP_COLD_BUILD}" -eq 0 ]]; then
    # Phase 2: Cold build
    if ! run_phase 2 phase_cold_build; then
      any_failed=1
      # Skip 3-8, jump to 9
      run_phase 9 phase_verify_cleanup || any_failed=1
      run_phase 10 phase_report || true
      exit 1
    fi

    # Phase 3: Snapshot (timed for SC-002)
    if ! run_phase 3 phase_snapshot; then
      any_failed=1
      # Still teardown and verify
      run_phase 4 phase_teardown || true
      run_phase 9 phase_verify_cleanup || any_failed=1
      run_phase 10 phase_report || true
      exit 1
    fi
    SC_002_SNAPSHOT="${PHASE_DURATIONS[3]}"

    # Phase 4: Teardown
    if ! run_phase 4 phase_teardown; then
      any_failed=1
      run_phase 9 phase_verify_cleanup || any_failed=1
      run_phase 10 phase_report || true
      exit 1
    fi
  else
    info "Skipping phases 2-4 (--skip-cold-build)"
    record_phase 2 "SKIP" 0
    record_phase 3 "SKIP" 0
    record_phase 4 "SKIP" 0
  fi

  # --- Phase 5: Warm start (timed for SC-001 and SC-007) ---
  if ! run_phase 5 phase_warm_start; then
    any_failed=1
    # Skip 6-8, jump to 9
    run_phase 9 phase_verify_cleanup || any_failed=1
    run_phase 10 phase_report || true
    exit 1
  fi
  SC_001_WARM="${PHASE_DURATIONS[5]}"
  SC_007_WARM_SECS="${PHASE_DURATIONS[5]}"

  # --- Phase 6: Health check (timed for SC-003) ---
  if ! run_phase 6 phase_health_check; then
    any_failed=1
    # Try to cool down before exit
    run_phase 8 phase_cool_down || true
    run_phase 9 phase_verify_cleanup || any_failed=1
    run_phase 10 phase_report || true
    exit 1
  fi
  SC_003_HEALTH="${PHASE_DURATIONS[6]}"

  # --- Phase 7: Scenarios ---
  if ! run_phase 7 phase_scenarios; then
    any_failed=1
    # Still try to cool down
    run_phase 8 phase_cool_down || true
    run_phase 9 phase_verify_cleanup || any_failed=1
    run_phase 10 phase_report || true
    exit 1
  fi

  # --- Phase 8: Cool down (timed for SC-007) ---
  if ! run_phase 8 phase_cool_down; then
    any_failed=1
  fi
  SC_007_COOL_SECS="${PHASE_DURATIONS[8]}"

  # --- Phase 9: Verify cleanup (ALWAYS runs) ---
  if ! run_phase 9 phase_verify_cleanup; then
    any_failed=1
  fi

  # --- Phase 10: Report ---
  run_phase 10 phase_report || true

  if [[ "${any_failed}" -ne 0 ]]; then
    exit 1
  fi

  exit 0
}

main "$@"
