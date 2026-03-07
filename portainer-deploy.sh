#!/bin/bash

# Portainer Stack Deployment Script
# Automates Portainer CE lifecycle via docker compose

set -euo pipefail

# Configuration
COMPOSE_FILE="${COMPOSE_FILE:-portainer-compose.yaml}"
PROJECT_NAME="${PROJECT_NAME:-portainer}"
PORTAINER_PORT="${PORTAINER_PORT:-55443}"
ACTION=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Privateness Network - Portainer Deployment${NC}"
echo "=============================================="

if [ ! -f "$COMPOSE_FILE" ]; then
    echo -e "${RED}Error: Compose file not found: $COMPOSE_FILE${NC}"
    exit 1
fi

INTERACTIVE=0
if [ "$#" -eq 0 ]; then
    INTERACTIVE=1
else
    ACTION="$1"
fi

run_compose() {
    local timeout_cmd=()
    local seconds="${TIMEOUT_SECONDS:-300}"
    if command -v timeout >/dev/null 2>&1; then
        timeout_cmd=(timeout "$seconds")
    fi
    "${timeout_cmd[@]}" docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" "$@"
}

show_qr() {
  # Optional: show QR code for quick access to Portainer
  HOST_IP=${HOST_IP:-}
  if [ -z "$HOST_IP" ]; then
    # try to detect a likely LAN IP (non-loopback)
    if command -v hostname >/dev/null 2>&1; then
      HOST_IP=$(hostname -I 2>/dev/null | awk '{for(i=1;i<=NF;i++) if ($i!~/^127\./) {print $i; exit}}')
    fi
  fi

  ACCESS_URL="https://localhost:$PORTAINER_PORT"
  if [ -n "$HOST_IP" ]; then
    ACCESS_URL="https://$HOST_IP:$PORTAINER_PORT"
  fi

  echo ""
  echo -e "${YELLOW}Quick Access URL:${NC} $ACCESS_URL"

  if command -v qrencode >/dev/null 2>&1; then
    echo -e "${YELLOW}QR code (scan to open Portainer):${NC}"
    qrencode -t ANSIUTF8 "$ACCESS_URL"
  else
    # Fallback to Python-based QR if available
    if command -v python3 >/dev/null 2>&1; then
      PY_TMP=$(mktemp)
      cat > "$PY_TMP" <<'PY'
import sys
try:
    import qrcode
except ImportError:
    sys.exit(1)
url = sys.argv[1] if len(sys.argv) > 1 else ''
img = qrcode.make(url)
try:
    import numpy as np
    arr = np.array(img.convert('L'))
    # crude ASCII render
    for row in arr:
        line = ''.join('  ' if px > 128 else '██' for px in row)
        print(line)
except Exception:
    img.show()
PY
      if python3 - <<PYCHK
import importlib, sys
sys.exit(0 if importlib.util.find_spec('qrcode') else 1)
PYCHK
      then
        python3 "$PY_TMP" "$ACCESS_URL"
      else
        echo -e "${YELLOW}(Tip) Install a QR tool for terminal output: 'sudo apt-get install -y qrencode' or 'pip install qrcode[pil]'${NC}"
      fi
      rm -f "$PY_TMP" 2>/dev/null || true
    else
      echo -e "${YELLOW}(Tip) Install a QR tool for terminal output: 'sudo apt-get install -y qrencode'${NC}"
    fi
  fi
}

do_action() {
  local action="$1"
  case "$action" in
    start)
        echo -e "${YELLOW}Starting Portainer stack...${NC}"
        run_compose up -d
        show_qr
        ;;
    stop)
        echo -e "${YELLOW}Stopping Portainer stack...${NC}"
        run_compose stop
        ;;
    status)
        echo -e "${YELLOW}Portainer stack status:${NC}"
        run_compose ps
        ;;
    clean-restart)
        echo -e "${YELLOW}Performing clean restart (down + up) of Portainer stack...${NC}"
        run_compose down
        run_compose up -d
        show_qr
        ;;
    *)
        echo "Invalid action: $action"
        echo "Usage: $0 {start|stop|status|clean-restart}"
        return 1
        ;;
  esac
}

show_menu() {
  while true; do
    echo ""
    echo "[ Portainer CE Menu ]"
    echo "  1) Start"
    echo "  2) Stop"
    echo "  3) Status"
    echo "  4) Clean restart"
    echo "  q) Quit"
    echo ""
    read -r -p "Select an option: " choice

    case "$choice" in
      1) do_action start ;;
      2) do_action stop ;;
      3) do_action status ;;
      4) do_action clean-restart ;;
      q|Q)
         echo "Exiting menu."
         break
         ;;
      *)
         echo -e "${RED}Invalid selection. Please choose 1, 2, 3, 4 or q.${NC}"
         ;;
    esac

    # Pause after each action so output is visible
    echo ""
    read -r -p "Press Enter to continue..." _dummy
  done
}

if [ "$INTERACTIVE" -eq 1 ]; then
  show_menu
  exit 0
fi

do_action "$ACTION"

