#!/usr/bin/env bash
# Purpose: Detect certificate-based SSH auth to support MFA bypass rules.
set -euo pipefail
if grep -q "publickey" /var/log/secure; then
  exit 0
fi
exit 1
