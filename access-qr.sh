#!/usr/bin/env bash

# Ness Quick Access: Start Portainer (if needed) and display a QR code for easy access
# Usage:
#   ./access-qr.sh
# Optional env vars:
#   PORTAINER_IMAGE=portainer/portainer-ce:latest
#   PORTAINER_HTTP_PORT=9000
#   PORTAINER_HTTPS_PORT=9443
#   PORTAINER_NAME=portainer-ce

set -euo pipefail

PORTAINER_IMAGE="${PORTAINER_IMAGE:-portainer/portainer-ce:latest}"
PORTAINER_HTTP_PORT="${PORTAINER_HTTP_PORT:-9000}"
PORTAINER_HTTPS_PORT="${PORTAINER_HTTPS_PORT:-9443}"
PORTAINER_NAME="${PORTAINER_NAME:-portainer-ce}"

need_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "[ERROR] Docker is required. Please install Docker and re-run this script." >&2
    echo "        https://docs.docker.com/engine/install/" >&2
    exit 1
  fi
}

start_portainer() {
  if docker ps --format '{{.Names}}' | grep -q "^${PORTAINER_NAME}$"; then
    echo "[OK] Portainer is already running as '${PORTAINER_NAME}'."
    return 0
  fi
  if docker ps -a --format '{{.Names}}' | grep -q "^${PORTAINER_NAME}$"; then
    echo "[INFO] Found existing Portainer container. Starting it..."
    docker start "$PORTAINER_NAME" >/dev/null
  else
    echo "[INFO] Running Portainer (${PORTAINER_IMAGE}) ..."
    docker run -d \
      -p ${PORTAINER_HTTPS_PORT}:9443 \
      -p ${PORTAINER_HTTP_PORT}:9000 \
      --name "${PORTAINER_NAME}" \
      --restart=unless-stopped \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v portainer_data:/data \
      "${PORTAINER_IMAGE}" >/dev/null
  fi
}

lan_ip() {
  if command -v hostname >/dev/null 2>&1; then
    hostname -I 2>/dev/null | awk '{for(i=1;i<=NF;i++) if ($i!~/^127\./) {print $i; exit}}'
  fi
}

print_qr() {
  local url="$1"
  echo "\nAccess Portainer at: $url\n"
  if command -v qrencode >/dev/null 2>&1; then
    echo "QR code (scan with your phone):"
    qrencode -t ANSIUTF8 "$url"
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    if python3 - <<PYCHK
import importlib, sys
sys.exit(0 if importlib.util.find_spec('qrcode') else 1)
PYCHK
    then
      python3 - "$url" <<'PY'
import sys
import qrcode
url = sys.argv[1]
img = qrcode.make(url)
try:
    import numpy as np
    arr = np.array(img.convert('L'))
    for row in arr:
        print(''.join('  ' if px > 128 else '██' for px in row))
except Exception:
    img.show()
PY
      return 0
    fi
  fi
  echo "(Tip) Install a QR tool: 'sudo apt-get install -y qrencode' or 'pip install qrcode[pil]'" >&2
}

main() {
  need_docker
  start_portainer
  # Prefer HTTPS when available
  local ip
  ip=$(lan_ip)
  local url_https="https://${ip:-localhost}:${PORTAINER_HTTPS_PORT}"
  local url_http="http://${ip:-localhost}:${PORTAINER_HTTP_PORT}"

  # Portainer CE exposes both; show both, QR for HTTPS
  echo "\nURLs:"
  echo "  - $url_https"
  echo "  - $url_http"
  print_qr "$url_https" || print_qr "$url_http" || true
}

main "$@"
