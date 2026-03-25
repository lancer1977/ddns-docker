#!/usr/bin/env bash
set -euo pipefail

SLEEP_SECONDS="${SLEEP_SECONDS:-300}"

if [[ ! "${SLEEP_SECONDS}" =~ ^[0-9]+$ ]]; then
  echo "SLEEP_SECONDS must be numeric"
  exit 1
fi

if [[ "${RUN_ON_STARTUP:-true}" == "true" ]]; then
  /scripts/ddns-sync.sh || true
fi

while true; do
  /scripts/ddns-sync.sh || true
  sleep "${SLEEP_SECONDS}"
done
