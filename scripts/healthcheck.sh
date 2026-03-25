#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${STATE_DIR:-/state}"
MAX_AGE_SECONDS="${HEALTH_MAX_AGE_SECONDS:-1800}"

if [[ ! -f "${STATE_DIR}/last_success_epoch" ]]; then
  exit 1
fi

last_success="$(cat "${STATE_DIR}/last_success_epoch")"
now="$(date +%s)"
age=$((now - last_success))

if (( age > MAX_AGE_SECONDS )); then
  exit 1
fi

exit 0
