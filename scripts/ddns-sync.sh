#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${STATE_DIR:-/state}"
mkdir -p "${STATE_DIR}"

log() {
  echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*"
}

read_secret() {
  local var_name="$1"
  local file_var="${var_name}_FILE"
  local direct="${!var_name:-}"
  local file_path="${!file_var:-}"

  if [[ -n "${file_path}" ]]; then
    if [[ ! -f "${file_path}" ]]; then
      log "ERROR: ${file_var} points to missing file: ${file_path}"
      exit 1
    fi
    local value
    value="$(tr -d '\r' < "${file_path}" | tr -d '\n')"
    printf '%s' "${value}"
    return
  fi

  printf '%s' "${direct}"
}

require_non_empty() {
  local name="$1"
  local value="$2"
  if [[ -z "${value}" ]]; then
    log "ERROR: missing required value: ${name}"
    exit 1
  fi
}

lower() {
  echo "$1" | tr '[:upper:]' '[:lower:]'
}

to_bool() {
  local value
  value="$(lower "${1:-}")"
  [[ "${value}" == "1" || "${value}" == "true" || "${value}" == "yes" ]]
}

is_uuid() {
  local value="$1"
  [[ "${value}" =~ ^[0-9a-fA-F-]{36}$ ]]
}

fqdn_for_label() {
  local label="$1"
  local zone="$2"
  if [[ "${label}" == "@" || -z "${label}" ]]; then
    echo "${zone}"
  elif [[ "${label}" == *".${zone}" ]]; then
    echo "${label}"
  else
    echo "${label}.${zone}"
  fi
}

cf_api() {
  local method="$1"
  local url="$2"
  local body="${3:-}"

  if [[ -n "${body}" ]]; then
    curl -fsS -X "${method}" "${url}" \
      -H "Authorization: Bearer ${CF_API_TOKEN}" \
      -H "Content-Type: application/json" \
      --data "${body}"
  else
    curl -fsS -X "${method}" "${url}" \
      -H "Authorization: Bearer ${CF_API_TOKEN}"
  fi
}

lookup_public_ipv4() {
  local source="${IPV4_LOOKUP_URL:-https://api.ipify.org}"
  curl -fsS "${source}" | tr -d '[:space:]'
}

lookup_public_ipv6() {
  local source="${IPV6_LOOKUP_URL:-https://api64.ipify.org}"
  curl -fsS "${source}" | tr -d '[:space:]'
}

get_record() {
  local type="$1"
  local name="$2"
  local response
  response="$(cf_api GET "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records?type=${type}&name=${name}")"
  local ok
  ok="$(echo "${response}" | jq -r '.success')"
  if [[ "${ok}" != "true" ]]; then
    log "ERROR: Cloudflare lookup failed for ${type} ${name}: ${response}"
    exit 1
  fi
  echo "${response}"
}

upsert_record() {
  local type="$1"
  local name="$2"
  local content="$3"
  local proxied="$4"
  local ttl="$5"

  local record_json
  record_json="$(get_record "${type}" "${name}")"
  local id
  id="$(echo "${record_json}" | jq -r '.result[0].id // empty')"
  local current_content
  current_content="$(echo "${record_json}" | jq -r '.result[0].content // empty')"
  local current_proxied
  current_proxied="$(echo "${record_json}" | jq -r '.result[0].proxied // false')"
  local current_ttl
  current_ttl="$(echo "${record_json}" | jq -r '.result[0].ttl // 1')"

  local payload
  payload="$(jq -n \
    --arg type "${type}" \
    --arg name "${name}" \
    --arg content "${content}" \
    --argjson proxied "${proxied}" \
    --argjson ttl "${ttl}" \
    '{type:$type,name:$name,content:$content,proxied:$proxied,ttl:$ttl}')"

  if [[ -n "${id}" ]]; then
    if [[ "${current_content}" == "${content}" && "${current_proxied}" == "${proxied}" && "${current_ttl}" == "${ttl}" ]]; then
      log "No change for ${type} ${name} -> ${content}"
      return
    fi

    log "Updating ${type} ${name} -> ${content}"
    cf_api PUT "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records/${id}" "${payload}" >/dev/null
  else
    log "Creating ${type} ${name} -> ${content}"
    cf_api POST "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records" "${payload}" >/dev/null
  fi
}

sync_ip_record() {
  local type="$1"
  local ip="$2"
  local cache_file="$3"

  if [[ -f "${cache_file}" ]]; then
    local last
    last="$(cat "${cache_file}")"
    if [[ "${last}" == "${ip}" ]]; then
      log "${type} unchanged (${ip}); skipping update."
      return
    fi
  fi

  upsert_record "${type}" "${CANONICAL_FQDN}" "${ip}" "${CF_PROXIED_BOOL}" "${CF_TTL}"
  echo "${ip}" > "${cache_file}"
}

sync_cname_records() {
  local raw="${CF_CNAME_LABELS:-}"
  if [[ -z "${raw}" ]]; then
    log "No CNAME labels configured; skipping CNAME fan-out."
    return
  fi

  IFS=',' read -r -a labels <<< "${raw}"
  for label in "${labels[@]}"; do
    label="$(echo "${label}" | xargs)"
    [[ -z "${label}" ]] && continue
    local fqdn
    fqdn="$(fqdn_for_label "${label}" "${CF_ZONE_NAME}")"
    upsert_record "CNAME" "${fqdn}" "${CANONICAL_FQDN}" "${CF_PROXIED_BOOL}" "${CF_TTL}"
  done
}

mark_success() {
  date +%s > "${STATE_DIR}/last_success_epoch"
}

CF_API_TOKEN="$(read_secret CF_API_TOKEN)"
CF_ZONE_ID="$(read_secret CF_ZONE_ID)"
CF_ZONE_NAME="${CF_ZONE_NAME:-}"
CF_CANONICAL_LABEL="${CF_CANONICAL_LABEL:-home}"
CF_CNAME_LABELS="${CF_CNAME_LABELS:-}"
CF_TTL="${CF_TTL:-1}"
CF_PROXIED="${CF_PROXIED:-true}"
CF_ENABLE_IPV4="${CF_ENABLE_IPV4:-true}"
CF_ENABLE_IPV6="${CF_ENABLE_IPV6:-false}"

require_non_empty "CF_API_TOKEN or CF_API_TOKEN_FILE" "${CF_API_TOKEN}"
require_non_empty "CF_ZONE_ID or CF_ZONE_ID_FILE" "${CF_ZONE_ID}"
require_non_empty "CF_ZONE_NAME" "${CF_ZONE_NAME}"

if ! is_uuid "${CF_ZONE_ID}"; then
  log "ERROR: CF_ZONE_ID does not look like a zone UUID."
  exit 1
fi

if [[ ! "${CF_TTL}" =~ ^[0-9]+$ ]]; then
  log "ERROR: CF_TTL must be numeric."
  exit 1
fi

CF_PROXIED_BOOL=false
if to_bool "${CF_PROXIED}"; then
  CF_PROXIED_BOOL=true
fi

CANONICAL_FQDN="$(fqdn_for_label "${CF_CANONICAL_LABEL}" "${CF_ZONE_NAME}")"
log "Starting sync for canonical host: ${CANONICAL_FQDN}"

if to_bool "${CF_ENABLE_IPV4}"; then
  ipv4="$(lookup_public_ipv4)"
  require_non_empty "public IPv4" "${ipv4}"
  sync_ip_record "A" "${ipv4}" "${STATE_DIR}/last_ipv4"
fi

if to_bool "${CF_ENABLE_IPV6}"; then
  ipv6="$(lookup_public_ipv6)"
  require_non_empty "public IPv6" "${ipv6}"
  sync_ip_record "AAAA" "${ipv6}" "${STATE_DIR}/last_ipv6"
fi

sync_cname_records
mark_success
log "Sync complete."
