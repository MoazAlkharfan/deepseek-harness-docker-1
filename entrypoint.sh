#!/bin/sh
set -e

# ============================================================
# DeepSeek Harness Docker Entrypoint
# ============================================================
# 1. Generate Caddyfile from template (with optional Basic Auth)
# 2. Optionally update DSH to latest
# 3. Start DSH web on 127.0.0.1:${DSH_PORT}
# 4. Start Caddy on :${PROXY_PORT}
#
# API keys are configured directly in the DSH Web UI.

echo "=== DeepSeek Harness Docker ==="
echo "DSH Home:      ${DSH_HOME:-/opt/dsh-home}"
echo "DSH Version:   $(dsh --version 2>&1 || echo unknown)"
echo "Permission:    ${DSH_PERMISSION_MODE:-danger-full-access}"
echo "DSH listen:    127.0.0.1:${DSH_PORT:-3079}"
echo "Proxy listen:  :${PROXY_PORT:-3080}"
echo "Auto-update:   ${DSH_UPDATE_ON_START:-false}"
echo "HMR:           --expose-internals (direct node flag)"
if [ -n "${PROXY_USERNAME}" ] && [ -n "${PROXY_PASSWORD}" ]; then
    echo "Basic Auth:    enabled (user: ${PROXY_USERNAME})"
else
    echo "Basic Auth:    disabled"
fi
echo "================================"

# Ensure DSH home directories exist
mkdir -p "${DSH_HOME}/sessions" "${DSH_HOME}/storages" "${DSH_HOME}/profiles"

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
# HMR service requires Node.js --expose-internals, which Node 22+ forbids
# via NODE_OPTIONS — must be passed directly to node. Use the real package
# path (the /usr/local/bin/dsh symlink would break import.meta.url).
# No --trusted-host is needed: Caddy rewrites Host/Origin to loopback
# upstream, so every /api request (settings/credentials included) is already
# seen as loopback by DSH — LAN access works with zero configuration.
DSH_BIN=/usr/local/lib/node_modules/@deepseek-ai/dsh/lib/bin.js

echo "Starting DSH web on ${DSH_HOST:-127.0.0.1}:${DSH_PORT}..."
node --expose-internals "${DSH_BIN}" web \
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