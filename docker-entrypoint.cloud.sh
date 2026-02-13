#!/usr/bin/env bash
set -euo pipefail

# ── Required env vars (opinionated: Telegram + ZAI are mandatory) ──
: "${TELEGRAM_BOT_TOKEN:?ERROR: TELEGRAM_BOT_TOKEN env var is required}"
: "${ZAI_API_KEY:?ERROR: ZAI_API_KEY env var is required}"

# Bridge persistent storage at /openclaw to OpenClaw's expected config path
# The persistent disk on Quave Cloud is mounted at /openclaw
CONFIG_DIR="/home/node/.openclaw"
STORAGE_DIR="/openclaw"

# Create the .openclaw dir inside persistent storage if it doesn't exist
mkdir -p "$STORAGE_DIR/.openclaw"
mkdir -p "$STORAGE_DIR/.openclaw/workspace"

# Symlink the config directory to persistent storage
ln -sfn "$STORAGE_DIR/.openclaw" "$CONFIG_DIR"

# Seed config if it doesn't exist yet
CONFIG_FILE="$STORAGE_DIR/.openclaw/openclaw.json"
if [ ! -f "$CONFIG_FILE" ]; then
  echo '{}' > "$CONFIG_FILE"
fi

# Dynamically detect the default gateway IP (Kubernetes ingress proxy) and inject
# it as a trusted proxy on every boot. OpenClaw's trustedProxies requires exact IPs
# (no CIDR support), and the proxy IP can change between pod schedules.
GATEWAY_IP=$(awk '$2 == "00000000" { # default route has destination 0.0.0.0
  gw = $3
  # convert little-endian hex to dotted decimal
  printf "%d.%d.%d.%d\n", "0x"substr(gw,7,2), "0x"substr(gw,5,2), "0x"substr(gw,3,2), "0x"substr(gw,1,2)
  exit
}' /proc/net/route 2>/dev/null || true)

# Build trustedProxies array from gateway IP
if [ -n "$GATEWAY_IP" ]; then
  PROXIES="[\"$GATEWAY_IP\"]"
else
  PROXIES="[]"
fi

# Merge full config into existing openclaw.json using node (jq not available).
# ZAI_API_KEY and TELEGRAM_BOT_TOKEN are read from runtime environment variables
# (set on Quave Cloud as env vars with sendToDeploy), so secrets stay out of the image.
node -e "
  const fs = require('fs');
  const path = '$CONFIG_FILE';
  let cfg = {};
  try { cfg = JSON.parse(fs.readFileSync(path, 'utf-8')); } catch {}

  // Gateway
  cfg.gateway = cfg.gateway || {};
  cfg.gateway.trustedProxies = $PROXIES;
  cfg.gateway.controlUi = Object.assign({}, cfg.gateway.controlUi, { allowInsecureAuth: true });

  // Env – inject secrets from runtime environment variables
  cfg.env = cfg.env || {};
  cfg.env.ZAI_API_KEY = process.env.ZAI_API_KEY;
  cfg.env.TELEGRAM_BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN;

  // Agents defaults
  cfg.agents = cfg.agents || {};
  cfg.agents.defaults = cfg.agents.defaults || {};
  cfg.agents.defaults.model = {
    primary: 'zai/glm-4.7',
    fallbacks: ['zai/glm-4.7-flash']
  };

  // Channels – Telegram is always enabled (opinionated setup)
  cfg.channels = cfg.channels || {};
  cfg.channels.telegram = Object.assign({}, cfg.channels.telegram, {
    enabled: true,
    botToken: process.env.TELEGRAM_BOT_TOKEN
  });

  fs.writeFileSync(path, JSON.stringify(cfg, null, 2) + '\n');
"

exec "$@"
