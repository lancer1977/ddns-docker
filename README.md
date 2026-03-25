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

## Authentication

**This container uses Bearer Token authentication exclusively.**

Cloudflare supports two authentication methods:
1. **Bearer Token (API Token)** - Recommended. Scoped permissions, can be rotated without affecting other services.
2. **Global API Key + Email** - Deprecated for this project. Provides full account access; not recommended for production.

### Why Bearer Token Only?
- **Security**: API tokens can be scoped to specific zones and permissions (DNS:Edit only).
- **Rotation**: Tokens can be rotated independently without changing your account password.
- **Audit**: Token usage is logged separately in Cloudflare audit trails.
- **Least privilege**: Tokens only have the permissions you grant them.

### Migration from Global API Key
If you previously used `CF_API_KEY` and `CF_EMAIL`:
1. Create a new API token in Cloudflare Dashboard (My Profile > API Tokens)
2. Grant Zone:DNS:Edit permissions for your specific zone
3. Create Docker secrets for the new token (see Swarm setup below)
4. Remove any old `CF_API_KEY` and `CF_EMAIL` environment variables
5. Rotate or delete the old Global API Key

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

## Health Checks

The container includes a Docker HEALTHCHECK that verifies:
1. Last successful sync is within `HEALTH_MAX_AGE_SECONDS` (default 30 minutes)
2. DNS resolution is working (can resolve `api.cloudflare.com`)
3. Cloudflare API endpoint is reachable

Check container health:
```bash
docker inspect --format='{{.State.Health.Status}}' <container_id>
```

## Log Rotation

Docker logging is configured with rotation to prevent log files from growing indefinitely:
- Driver: `json-file`
- Max size: `10m` per file
- Max files: `3` (keeps up to 30MB of logs total)

Logs can be viewed with:
```bash
docker service logs -f ddns_cloudflare-ddns
```

## Notes
- Rotate any previously exposed API keys/tokens.
- Prefer token auth over global API key/email.
