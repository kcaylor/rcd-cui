#!/usr/bin/env bash
set -euo pipefail

# Docker wrapper for cloud demo infrastructure commands
# Builds the container if needed and runs commands with proper mounts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${INFRA_DIR}/.." && pwd)"

IMAGE_NAME="rcd-demo-infra"
IMAGE_TAG="latest"
FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"

# Check if Docker is available
if ! command -v docker >/dev/null 2>&1; then
  printf 'ERROR: Docker is not installed or not in PATH.\n' >&2
  printf 'Install Docker from: https://docs.docker.com/get-docker/\n' >&2
  exit 3
fi

# Check if Docker daemon is running
if ! docker info >/dev/null 2>&1; then
  printf 'ERROR: Docker daemon is not running.\n' >&2
  printf 'Start Docker Desktop or the Docker daemon and try again.\n' >&2
  exit 3
fi

build_image() {
  printf '==> Building Docker image %s...\n' "${FULL_IMAGE}"
  docker build -t "${FULL_IMAGE}" "${INFRA_DIR}"
}

image_exists() {
  docker image inspect "${FULL_IMAGE}" >/dev/null 2>&1
}

# Build image if it doesn't exist
if ! image_exists; then
  build_image
fi

# Handle --rebuild flag
if [[ "${1:-}" == "--rebuild" ]]; then
  build_image
  shift
fi

# If no command specified, show help
if [[ $# -eq 0 ]]; then
  printf 'Usage: %s [--rebuild] <command> [args...]\n' "$(basename "$0")"
  printf '\n'
  printf 'Commands are run inside the Docker container with proper mounts.\n'
  printf '\n'
  printf 'Options:\n'
  printf '  --rebuild    Force rebuild of the Docker image\n'
  printf '\n'
  printf 'Examples:\n'
  printf '  %s ./infra/scripts/demo-cloud-up.sh\n' "$(basename "$0")"
  printf '  %s terraform -chdir=infra/terraform plan\n' "$(basename "$0")"
  printf '  %s ansible --version\n' "$(basename "$0")"
  exit 0
fi

# Source .env file if present (same as the shell scripts do)
ENV_FILE="${REPO_ROOT}/infra/.env"
if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
  set +a
fi

# Prepare environment variables to pass through
ENV_ARGS=()

# Pass HCLOUD_TOKEN if set in environment
if [[ -n "${HCLOUD_TOKEN:-}" ]]; then
  ENV_ARGS+=(-e "HCLOUD_TOKEN=${HCLOUD_TOKEN}")
fi

# Pass TF_VAR_ variables if set
while IFS='=' read -r name value; do
  if [[ "${name}" == TF_VAR_* ]]; then
    ENV_ARGS+=(-e "${name}=${value}")
  fi
done < <(env)

# Run the command in Docker
# Mounts:
#   - Full repo at /workspace (for scripts, playbooks, etc.)
#   - .env file if present
#   - SSH directory for key persistence
# Options:
#   - Interactive TTY for prompts (only if TTY available)
#   - Remove container after exit

# Use -it only if we have a TTY
TTY_ARGS=()
if [[ -t 0 ]]; then
  TTY_ARGS+=(-it)
fi

exec docker run \
  --rm \
  "${TTY_ARGS[@]+"${TTY_ARGS[@]}"}" \
  -v "${REPO_ROOT}:/workspace" \
  -w /workspace \
  "${ENV_ARGS[@]+"${ENV_ARGS[@]}"}" \
  "${FULL_IMAGE}" \
  "$@"
