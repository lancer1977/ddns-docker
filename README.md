# Cloudflare DDNS for Home + Swarm

## What this does
- Maintains one canonical dynamic DNS host (for example `home.example.com`) as `A` and optional `AAAA`.
- Fans out service hostnames as `CNAME` records pointing to the canonical host.
- Updates Cloudflare only when your public IP changes.
- Runs as a single Swarm service with Docker secrets.

## Why this pattern is reliable
- Only one record tracks your changing residential IP.
- Service hostnames stay stable and only depend on a CNAME target.
- Minimizes Cloudflare API writes and reduces DNS drift.

## Required Cloudflare token scope
Create an API token with:
- Zone: `DNS:Edit`
- Zone Resources: specific zone only

## Swarm setup

### 1. Create secrets
```bash
printf '%s' 'YOUR_CLOUDFLARE_API_TOKEN' | docker secret create cf_api_token -
printf '%s' 'YOUR_CLOUDFLARE_ZONE_ID' | docker secret create cf_zone_id -
```

### 2. Edit stack config
Update values in `docker-compose`:
- `CF_ZONE_NAME`
- `CF_CANONICAL_LABEL` (example: `home`)
- `CF_CNAME_LABELS` (example: `dashy,api,identity`)
- `CF_ENABLE_IPV6` if needed

### 3. Deploy
```bash
docker stack deploy -c docker-compose ddns
```

### 4. Verify
```bash
docker service ls | grep ddns
docker service logs -f ddns_cloudflare-ddns
```

## Environment reference
- `CF_ZONE_NAME`: DNS zone name, e.g. `example.com`
- `CF_CANONICAL_LABEL`: label for the dynamic host (`home` => `home.example.com`)
- `CF_CNAME_LABELS`: comma-separated labels to point at canonical host
- `CF_API_TOKEN_FILE`: path to Docker secret for API token
- `CF_ZONE_ID_FILE`: path to Docker secret for zone id
- `CF_ENABLE_IPV4`: `true/false`
- `CF_ENABLE_IPV6`: `true/false`
- `CF_PROXIED`: `true/false`
- `CF_TTL`: numeric TTL (`1` means auto)
- `SLEEP_SECONDS`: poll interval in seconds
- `HEALTH_MAX_AGE_SECONDS`: max age of successful sync before unhealthy

## Notes
- Rotate any previously exposed API keys/tokens.
- Prefer token auth over global API key/email.
