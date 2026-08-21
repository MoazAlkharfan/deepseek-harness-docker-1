# DeepSeek Harness Docker Image
# ===============================
# Multi-stage build: Node.js for DSH + Caddy for reverse proxy
#
# Build args:
#   DSH_VERSION  - DSH npm version to install (default: latest)
#   CACHE_BUST   - bust npm install cache (for scheduled builds)
#
# Environment variables:
#   DSH_PORT           - DSH internal listen port on 127.0.0.1 (default: 3079)
#   PROXY_PORT         - Caddy proxy external listen port (default: 3080)
#   PROXY_USERNAME     - Basic Auth username (optional; unset = no auth)
#   PROXY_PASSWORD     - Basic Auth password (optional; unset = no auth)
#   DSH_UPDATE_ON_START - set "true" to npm-update DSH on container start

FROM node:22-alpine AS builder

ARG DSH_VERSION=latest
ARG CACHE_BUST=0

# Enable pnpm via corepack (cached)
RUN corepack enable && corepack prepare pnpm@latest --activate

# Install DSH CLI globally
# --mount=type=cache reuses npm downloads across builds
RUN --mount=type=cache,target=/root/.npm,sharing=locked \
    echo "cache bust: ${CACHE_BUST}" && \
    npm install -g @deepseek-ai/dsh@${DSH_VERSION}

# Pre-create DSH home directories (profile auto-initializes on first boot)
ENV DSH_HOME=/opt/dsh-home
RUN mkdir -p "$DSH_HOME/profiles" "$DSH_HOME/sessions" "$DSH_HOME/storages"


FROM node:22-alpine

# Install Caddy, wget, and gettext (envsubst for Caddyfile templating)
RUN apk add --no-cache caddy wget gettext

# Copy DSH from builder
COPY --from=builder /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=builder /usr/local/bin/dsh /usr/local/bin/dsh
COPY --from=builder /opt/dsh-home /opt/dsh-home

# Set DSH home
ENV DSH_HOME=/opt/dsh-home

# Passwordless mode: danger-full-access = no approval prompts
ENV DSH_PERMISSION_MODE=danger-full-access

# Default ports
ENV DSH_HOST=127.0.0.1
ENV DSH_PORT=3079
ENV PROXY_PORT=3080

# Caddy will listen on PROXY_PORT
EXPOSE 3080

# Copy Caddyfile template
COPY Caddyfile.template /etc/caddy/Caddyfile.template

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Working directory for DSH sessions
WORKDIR /workspace
RUN mkdir -p /workspace

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:${DSH_PORT:-3079}/ || exit 1

ENTRYPOINT ["/entrypoint.sh"]