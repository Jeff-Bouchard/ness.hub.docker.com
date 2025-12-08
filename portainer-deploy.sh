#!/bin/bash

# Portainer Stack Deployment Script
# Automates deployment via Portainer API

set -e

# Configuration
PORTAINER_URL="${PORTAINER_URL:-http://localhost:9000}"
PORTAINER_API_KEY="${PORTAINER_API_KEY}"
STACK_NAME="${STACK_NAME:-privateness-network}"
STACK_FILE="${STACK_FILE:-portainer-stack.yml}"
ENDPOINT_ID="${ENDPOINT_ID:-1}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Privateness Network - Portainer Deployment${NC}"
echo "=============================================="

# Check prerequisites
if [ -z "$PORTAINER_API_KEY" ]; then
    echo -e "${RED}Error: PORTAINER_API_KEY not set${NC}"
    echo "Get your API key from Portainer: User → My account → API tokens"
    exit 1
fi

if [ ! -f "$STACK_FILE" ]; then
    echo -e "${RED}Error: Stack file not found: $STACK_FILE${NC}"
    exit 1
fi

echo -e "${YELLOW}Checking Portainer connection...${NC}"
if ! curl -s -f -H "X-API-Key: $PORTAINER_API_KEY" "$PORTAINER_URL/api/status" > /dev/null; then
    echo -e "${RED}Error: Cannot connect to Portainer at $PORTAINER_URL${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Connected to Portainer${NC}"

# Check if stack exists
STACK_ID=$(curl -s -H "X-API-Key: $PORTAINER_API_KEY" \
    "$PORTAINER_URL/api/stacks" | \
    jq -r ".[] | select(.Name==\"$STACK_NAME\") | .Id")

if [ -n "$STACK_ID" ]; then
    echo -e "${YELLOW}Stack '$STACK_NAME' already exists (ID: $STACK_ID)${NC}"
    read -p "Update existing stack? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Updating stack...${NC}"
        
        RESPONSE=$(curl -s -X PUT \
            -H "X-API-Key: $PORTAINER_API_KEY" \
            -H "Content-Type: application/json" \
            -d "{
                \"StackFileContent\": $(jq -Rs . < "$STACK_FILE"),
                \"Env\": [],
                \"Prune\": false,
                \"PullImage\": true
            }" \
            "$PORTAINER_URL/api/stacks/$STACK_ID?endpointId=$ENDPOINT_ID")
        
        if echo "$RESPONSE" | jq -e '.Id' > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Stack updated successfully${NC}"
        else
            echo -e "${RED}Error updating stack:${NC}"
            echo "$RESPONSE" | jq .
            exit 1
        fi
    else
        echo "Deployment cancelled"
        exit 0
    fi
else
    echo -e "${YELLOW}Creating new stack '$STACK_NAME'...${NC}"
    
    RESPONSE=$(curl -s -X POST \
        -H "X-API-Key: $PORTAINER_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"Name\": \"$STACK_NAME\",
            \"StackFileContent\": $(jq -Rs . < "$STACK_FILE"),
            \"Env\": [],
            \"FromAppTemplate\": false
        }" \
        "$PORTAINER_URL/api/stacks?type=2&method=string&endpointId=$ENDPOINT_ID")
    
    if echo "$RESPONSE" | jq -e '.Id' > /dev/null 2>&1; then
        STACK_ID=$(echo "$RESPONSE" | jq -r '.Id')
        echo -e "${GREEN}✓ Stack created successfully (ID: $STACK_ID)${NC}"
    else
        echo -e "${RED}Error creating stack:${NC}"
        echo "$RESPONSE" | jq .
        exit 1
    fi
fi

# Wait for deployment
echo -e "${YELLOW}Waiting for services to start...${NC}"
sleep 5

# Check stack status
STACK_STATUS=$(curl -s -H "X-API-Key: $PORTAINER_API_KEY" \
    "$PORTAINER_URL/api/stacks/$STACK_ID" | jq -r '.Status')

echo ""
echo -e "${GREEN}Deployment Summary${NC}"
echo "==================="
echo "Stack Name: $STACK_NAME"
echo "Stack ID: $STACK_ID"
echo "Status: $STACK_STATUS"
echo ""
echo -e "${GREEN}Access Points:${NC}"
echo "  Emercoin RPC: http://localhost:6662"
echo "  I2P Console: http://localhost:7657"
echo "  Privateness: http://localhost:8080"
echo "  Portainer: $PORTAINER_URL"
echo ""
echo -e "${GREEN}✓ Deployment complete!${NC}"

# Optional: show QR code for quick access to Portainer
HOST_IP=${HOST_IP:-}
if [ -z "$HOST_IP" ]; then
  # try to detect a likely LAN IP (non-loopback)
  if command -v hostname >/dev/null 2>&1; then
    HOST_IP=$(hostname -I 2>/dev/null | awk '{for(i=1;i<=NF;i++) if ($i!~/^127\./) {print $i; exit}}')
  fi
fi

ACCESS_URL="$PORTAINER_URL"
if [ -n "$HOST_IP" ]; then
  # If user left default http://localhost:9000, also print a LAN-friendly URL
  case "$PORTAINER_URL" in
    http://localhost:9000) ACCESS_URL="http://$HOST_IP:9000" ;;
    https://localhost:9443) ACCESS_URL="https://$HOST_IP:9443" ;;
  esac
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
