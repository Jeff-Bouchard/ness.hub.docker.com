#!/bin/sh
set -e

PASS=${SOFTETHER_ADMIN_PASSWORD:-}
WG_ENABLE=${SOFTETHER_ENABLE_WG:-1}

if [ -z "$PASS" ]; then
  echo "[softether] SOFTETHER_ADMIN_PASSWORD is required" >&2
  exit 1
fi

# Start server
/usr/bin/vpnserver start
sleep 3

# Set server admin password (idempotent)
/usr/bin/vpncmd localhost:5555 /SERVER /CMD ServerPasswordSet "$PASS" || true

# Enable WireGuard if supported (best effort)
if [ "$WG_ENABLE" = "1" ]; then
  /usr/bin/vpncmd localhost:5555 /SERVER /PASSWORD:"$PASS" /CMD WireGuardEnable true >/dev/null 2>&1 || true
fi

# Keep container alive
exec tail -f /dev/null
