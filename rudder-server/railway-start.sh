#!/bin/bash
# Railway wrapper for rudder-server. Two modes:
#   * WORKSPACE_TOKEN set   -> connected to RudderStack's hosted control plane
#                              (sources and destinations are managed at app.rudderstack.com).
#   * WORKSPACE_TOKEN empty -> standalone: a workspace config is generated on the volume with
#                              one HTTP source (write key = RUDDER_WRITE_KEY) and, if
#                              RUDDER_WEBHOOK_URL is set, one Webhook destination.
set -euo pipefail
log() { echo "[railway-start] $*"; }

DATA_DIR="${RUDDER_DATA_DIR:-/data}"
mkdir -p "$DATA_DIR"

# --- jobs database: DATABASE_URL (Railway Postgres reference) unless JOBS_DB_* are set ---------
if [ -n "${DATABASE_URL:-}" ]; then
  url="${DATABASE_URL#*://}"
  creds="${url%%@*}"; rest="${url#*@}"
  hostport="${rest%%/*}"; dbq="${rest#*/}"
  : "${JOBS_DB_USER:=${creds%%:*}}"
  : "${JOBS_DB_PASSWORD:=${creds#*:}}"
  : "${JOBS_DB_HOST:=${hostport%%:*}}"
  if [ "$hostport" != "${hostport#*:}" ]; then : "${JOBS_DB_PORT:=${hostport##*:}}"; fi
  : "${JOBS_DB_DB_NAME:=${dbq%%\?*}}"
fi
: "${JOBS_DB_PORT:=5432}"
: "${JOBS_DB_SSL_MODE:=disable}"   # private network only
for v in JOBS_DB_HOST JOBS_DB_USER JOBS_DB_PASSWORD JOBS_DB_DB_NAME; do
  if [ -z "${!v:-}" ]; then log "FATAL: $v is empty: set DATABASE_URL to \${{Postgres.DATABASE_URL}}"; exit 1; fi
done
export JOBS_DB_HOST JOBS_DB_USER JOBS_DB_PASSWORD JOBS_DB_DB_NAME JOBS_DB_PORT JOBS_DB_SSL_MODE

# --- fixed settings (override any of them with a service variable) ---------------------------
export RSERVER_GATEWAY_WEB_PORT="${PORT:-8080}"
export RUDDER_TMPDIR="${RUDDER_TMPDIR:-$DATA_DIR/tmp}"
export GO_ENV="${GO_ENV:-production}"
export LOG_LEVEL="${LOG_LEVEL:-INFO}"
export INSTANCE_ID="${INSTANCE_ID:-railway}"
export RSERVER_GATEWAY_WEBHOOK_SOURCE_LIST_FOR_PARSING_PARAMS="${RSERVER_GATEWAY_WEBHOOK_SOURCE_LIST_FOR_PARSING_PARAMS:-Shopify}"
export RSERVER_DIAGNOSTICS_ENABLE_DIAGNOSTICS="${RSERVER_DIAGNOSTICS_ENABLE_DIAGNOSTICS:-false}"
export RSERVER_ENABLE_STATS="${RSERVER_ENABLE_STATS:-false}"
export RSERVER_GATEWAY_INTERNAL_ENDPOINTS_ENABLED=false   # /internal/* has no write-key auth
mkdir -p "$RUDDER_TMPDIR"

# --- control plane or standalone ---------------------------------------------------------------
if [ -n "${WORKSPACE_TOKEN:-}" ]; then
  export CONFIG_BACKEND_URL="${CONFIG_BACKEND_URL:-https://api.rudderstack.com}"
  export RSERVER_BACKEND_CONFIG_CONFIG_FROM_FILE=false
  log "mode: control plane ($CONFIG_BACKEND_URL)"
else
  unset WORKSPACE_TOKEN
  if [ -z "${RUDDER_WRITE_KEY:-}" ]; then log "FATAL: RUDDER_WRITE_KEY is empty (standalone mode needs it)"; exit 1; fi
  case "$RUDDER_WRITE_KEY" in *[!A-Za-z0-9_-]*) log "FATAL: RUDDER_WRITE_KEY may only use letters, digits, - and _"; exit 1;; esac
  cfg="${RSERVER_BACKEND_CONFIG_CONFIG_JSONPATH:-$DATA_DIR/workspaceConfig.json}"
  if [ "${RUDDER_CONFIG_FILE_MANAGED:-false}" = "true" ] && [ -s "$cfg" ]; then
    log "mode: standalone, using your own $cfg (RUDDER_CONFIG_FILE_MANAGED=true)"
  else
    json_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
    ts="2026-01-01T00:00:00.000Z"
    dest=""
    if [ -n "${RUDDER_WEBHOOK_URL:-}" ]; then
      dest=$(cat <<JSON
{"config":{"webhookUrl":"$(json_escape "$RUDDER_WEBHOOK_URL")","webhookMethod":"POST","headers":[]},"secretConfig":{},
 "id":"railwaywebhookdestination01","name":"Webhook","enabled":true,"workspaceId":"railway-workspace","deleted":false,
 "createdAt":"$ts","updatedAt":"$ts","transformations":[],"isConnectionEnabled":true,"isProcessorEnabled":true,
 "destinationDefinition":{"config":{"destConfig":{"defaultConfig":["webhookUrl","webhookMethod","headers"]},"secretKeys":["headers.to"],
  "excludeKeys":[],"includeKeys":[],"transformAt":"processor","transformAtV1":"processor",
  "supportedSourceTypes":["android","ios","web","unity","amp","cloud","warehouse","reactnative","flutter"],
  "supportedMessageTypes":["alias","group","identify","page","screen","track"],"saveDestinationResponse":false},
  "configSchema":null,"id":"railwaywebhookdefinition001","name":"WEBHOOK","displayName":"Webhook","category":null,
  "createdAt":"$ts","updatedAt":"$ts"}}
JSON
)
    fi
    cat > "$cfg.tmp" <<JSON
{"enableMetrics":false,"workspaceId":"railway-workspace","updatedAt":"$ts","libraries":[],
 "sources":[{"config":{},"id":"railwayhttpsource0000000001","name":"HTTP","writeKey":"$RUDDER_WRITE_KEY","enabled":true,
  "sourceDefinitionId":"railwayhttpsourcedefinition","workspaceId":"railway-workspace","deleted":false,
  "createdAt":"$ts","updatedAt":"$ts",
  "sourceDefinition":{"id":"railwayhttpsourcedefinition","name":"HTTP","displayName":"HTTP","category":"","options":null,"createdAt":"$ts","updatedAt":"$ts"},
  "destinations":[${dest}]}]}
JSON
    mv "$cfg.tmp" "$cfg"; chmod 600 "$cfg"
    if [ -n "$dest" ]; then log "mode: standalone, HTTP source + Webhook destination"; else log "mode: standalone, HTTP source (no destination: set RUDDER_WEBHOOK_URL or WORKSPACE_TOKEN)"; fi
  fi
  export RSERVER_BACKEND_CONFIG_CONFIG_FROM_FILE=true
  export RSERVER_BACKEND_CONFIG_CONFIG_JSONPATH="$cfg"
  # No control plane: keep the debugger/uploaders from calling api.rudderstack.com without a token.
  export CONFIG_BACKEND_URL="${CONFIG_BACKEND_URL:-http://127.0.0.1:1}"
fi

# --- wait for Postgres (Railway starts services in parallel) ----------------------------------
for i in $(seq 1 60); do
  if PGPASSWORD="$JOBS_DB_PASSWORD" pg_isready -q -h "$JOBS_DB_HOST" -p "$JOBS_DB_PORT" -U "$JOBS_DB_USER" -d "$JOBS_DB_DB_NAME"; then break; fi
  [ "$i" = 60 ] && { log "FATAL: Postgres at $JOBS_DB_HOST:$JOBS_DB_PORT not ready after 5 minutes"; exit 1; }
  log "waiting for Postgres ($i/60)"; sleep 5
done

log "starting rudder-server on port $RSERVER_GATEWAY_WEB_PORT"
exec /docker-entrypoint.sh "$@"
