#!/bin/sh
set -e

# ============================================================
# DeepSeek Harness Docker Entrypoint
# ============================================================
# 1. Write credentials from env vars
# 2. Generate Caddyfile from template (with optional Basic Auth)
# 3. Start DSH web on 127.0.0.1:${DSH_PORT}
# 4. Start Caddy on :${PROXY_PORT}
#
# Passwordless mode: DSH_PERMISSION_MODE=danger-full-access

echo "=== DeepSeek Harness Docker ==="
echo "DSH Home:      ${DSH_HOME:-/opt/dsh-home}"
echo "DSH Version:   $(dsh --version 2>&1 || echo unknown)"
echo "Permission:    ${DSH_PERMISSION_MODE:-danger-full-access}"
echo "DSH listen:    127.0.0.1:${DSH_PORT:-3079}"
echo "Proxy listen:  :${PROXY_PORT:-3080}"
echo "Auto-update:   ${DSH_UPDATE_ON_START:-false}"
if [ -n "${PROXY_USERNAME}" ] && [ -n "${PROXY_PASSWORD}" ]; then
    echo "Basic Auth:    enabled (user: ${PROXY_USERNAME})"
else
    echo "Basic Auth:    disabled"
fi
echo "================================"

# Ensure DSH home directories exist
mkdir -p "${DSH_HOME}/sessions" "${DSH_HOME}/storages" "${DSH_HOME}/profiles"

# --- Credentials ---
CREDS_FILE="${DSH_HOME}/.credentials.yaml"
CREDS_CONTENT=""
if [ -n "${DEEPSEEK_API_KEY}" ]; then
    CREDS_CONTENT="DEEPSEEK_API_KEY: ${DEEPSEEK_API_KEY}"
fi
if [ -n "${TEAMOROUTER_API_KEY}" ]; then
    if [ -n "${CREDS_CONTENT}" ]; then
        CREDS_CONTENT="${CREDS_CONTENT}, TEAMOROUTER_API_KEY: ${TEAMOROUTER_API_KEY}"
    else
        CREDS_CONTENT="TEAMOROUTER_API_KEY: ${TEAMOROUTER_API_KEY}"
    fi
fi
if [ -n "${CREDS_CONTENT}" ]; then
    echo "Writing credentials to ${CREDS_FILE}..."
    mkdir -p "${DSH_HOME}"
    echo "{ ${CREDS_CONTENT} }" > "${CREDS_FILE}"
fi

# --- Generate Caddyfile ---
DSH_PORT="${DSH_PORT:-3079}"
PROXY_PORT="${PROXY_PORT:-3080}"

if [ -n "${PROXY_USERNAME}" ] && [ -n "${PROXY_PASSWORD}" ]; then
    # Generate password hash for Caddy
    HASH=$(caddy hash-password --plaintext "${PROXY_PASSWORD}" 2>/dev/null || echo "")
    if [ -n "${HASH}" ]; then
        export PROXY_AUTH="basicauth {
            ${PROXY_USERNAME} ${HASH}
        }"
    else
        echo "WARNING: caddy hash-password failed, falling back to plaintext"
        export PROXY_AUTH="basicauth {
            ${PROXY_USERNAME} ${PROXY_PASSWORD}
        }"
    fi
else
    export PROXY_AUTH=""
fi

export DSH_PORT PROXY_PORT
envsubst '${DSH_PORT} ${PROXY_PORT} ${PROXY_AUTH}' \
    < /etc/caddy/Caddyfile.template \
    > /etc/caddy/Caddyfile

echo "Generated Caddyfile:"
cat /etc/caddy/Caddyfile

# --- Optional: update DSH inside the container ---
if [ "${DSH_UPDATE_ON_START}" = "true" ]; then
    echo "Updating DSH to latest..."
    npm install -g @deepseek-ai/dsh@latest 2>&1 || echo "WARNING: DSH update failed, continuing with current version"
    echo "DSH version: $(dsh --version 2>&1 || echo unknown)"
fi

# --- Start DSH web ---
echo "Starting DSH web on ${DSH_HOST:-127.0.0.1}:${DSH_PORT}..."
dsh web \
    --host "${DSH_HOST:-127.0.0.1}" \
    --port "${DSH_PORT}" \
    --no-open \
    &
DSH_PID=$!

# Wait for DSH to be ready
echo "Waiting for DSH to be ready..."
for i in $(seq 1 30); do
    if wget --no-verbose --tries=1 --spider "http://${DSH_HOST:-127.0.0.1}:${DSH_PORT}/" > /dev/null 2>&1; then
        echo "DSH is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "WARNING: DSH did not respond within 30s, starting Caddy anyway..."
    fi
    sleep 1
done

# --- Start Caddy ---
echo "Starting Caddy on :${PROXY_PORT}..."
exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile