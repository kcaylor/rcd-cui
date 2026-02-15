#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/configure_branch_protection.sh [options]

Options:
  -r, --repo <owner/repo>   GitHub repository (default: inferred from git remote)
  -b, --branch <name>       Branch to protect (default: main)
      --dry-run             Print payload and API target without applying changes
  -h, --help                Show this help message

This script configures branch protection with:
  - Required status checks: lint, syntax-check, yaml-validation
  - Required approving reviews: 1
  - Branches must be up to date before merging
  - Admin enforcement enabled (no bypass)
  - Force pushes and deletions disabled
EOF
}

infer_repo() {
  if command -v gh >/dev/null 2>&1; then
    if gh_repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null); then
      if [[ -n "${gh_repo}" ]]; then
        echo "${gh_repo}"
        return 0
      fi
    fi
  fi

  remote_url=$(git config --get remote.origin.url || true)
  if [[ -z "${remote_url}" ]]; then
    return 1
  fi

  if [[ "${remote_url}" =~ github.com[:/]([^/]+/[^/.]+)(\.git)?$ ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi

  return 1
}

repo=""
branch="main"
dry_run="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -r|--repo)
      repo="${2:-}"
      shift 2
      ;;
    -b|--branch)
      branch="${2:-}"
      shift 2
      ;;
    --dry-run)
      dry_run="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ -z "${repo}" ]]; then
  if ! repo=$(infer_repo); then
    echo "ERROR: Could not infer repository. Pass --repo <owner/repo>." >&2
    exit 2
  fi
fi

payload=$(cat <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "lint",
      "syntax-check",
      "yaml-validation"
    ]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": false,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1,
    "require_last_push_approval": false
  },
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": true,
  "lock_branch": false,
  "allow_fork_syncing": true
}
JSON
)

endpoint="repos/${repo}/branches/${branch}/protection"

if [[ "${dry_run}" == "true" ]]; then
  echo "DRY RUN: gh api --method PUT ${endpoint}"
  echo "${payload}"
  exit 0
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: GitHub CLI (gh) is required." >&2
  exit 2
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: gh is not authenticated. Run: gh auth login" >&2
  exit 2
fi

gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "${endpoint}" \
  --input - <<<"${payload}"

echo "Branch protection configured for ${repo}:${branch}"
