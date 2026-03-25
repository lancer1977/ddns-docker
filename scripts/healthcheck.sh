#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${STATE_DIR:-/state}"
MAX_AGE_SECONDS="${HEALTH_MAX_AGE_SECONDS:-1800}"

# Check 1: Last successful sync within threshold
if [[ ! -f "${STATE_DIR}/last_success_epoch" ]]; then
  echo "healthcheck: missing last_success_epoch"
  exit 1
fi

last_success="$(cat "${STATE_DIR}/last_success_epoch")"
now="$(date +%s)"
age=$((now - last_success))

if (( age > MAX_AGE_SECONDS )); then
  echo "healthcheck: last sync too old (${age}s > ${MAX_AGE_SECONDS}s)"
  exit 1
fi

# Check 2: DNS resolution works (basic connectivity)
# Resolve Cloudflare API endpoint to verify DNS
if ! timeout 5 nslookup api.cloudflare.com >/dev/null 2>&1; then
  echo "healthcheck: DNS resolution failed"
  exit 1
fi

# Check 3: API endpoint reachable (network connectivity)
# Use HEAD request to verify Cloudflare API is accessible
if ! timeout 10 curl -fsSI https://api.cloudflare.com/client/v4/user 2>/dev/null | grep -q "HTTP"; then
  echo "healthcheck: API endpoint unreachable"
  exit 1
fi

exit 0
