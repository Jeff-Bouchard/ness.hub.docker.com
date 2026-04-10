#!/usr/bin/env bash
# Full end-to-end coverage for current stack (no Amnezia)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"
LOG_FILE="${SCRIPT_DIR}/full-e2e.log"
DNS_PORT="${DNS_PROXY_HOST_PORT:-1053}"
SOFTETHER_PORT="${SOFTETHER_VPN_PORT:-443}"
SSH_GATEWAY_PORT="${SSH_GATEWAY_PORT:-2222}"
EMERCOIN_P2P_PORT="${EMERCOIN_PORT_P2P:-6661}"
EMERCOIN_RPC_PORT="${EMERCOIN_PORT_RPC:-6662}"
PRIVATENESS_RPC_PORT="${PRIVATENESS_PORT_RPC:-6660}"
PYUHEPRNG_PORT="${PYUHEPRNG_PORT:-5000}"
PRIVATENESSTOOLS_PORT="${PRIVATENESSTOOLS_PORT:-8888}"
SKYWIRE_PORT="${SKYWIRE_PORT:-8000}"
YGGDRASIL_PORT="${YGGDRASIL_PORT:-9001}"
I2P_CONSOLE_PORT="${I2P_CONSOLE_PORT:-7657}"
COMPOSE_CMD=()

cyan="\033[1;36m"
green="\033[1;32m"
yellow="\033[1;33m"
red="\033[1;31m"
reset="\033[0m"

log() { echo -e "${cyan}[$(date '+%H:%M:%S')]${reset} $1" | tee -a "$LOG_FILE"; }
pass() { echo -e "${green}[PASS]${reset} $1" | tee -a "$LOG_FILE"; }
warn() { echo -e "${yellow}[WARN]${reset} $1" | tee -a "$LOG_FILE"; }
fail() { echo -e "${red}[FAIL]${reset} $1" | tee -a "$LOG_FILE"; exit 1; }

require() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

detect_runtime() {
  # Prefer podman-compose on this host to avoid podman compose delegating to docker-compose
  if command -v podman >/dev/null 2>&1 && podman info >/dev/null 2>&1; then
    RUNTIME="podman"

    if command -v podman-compose >/dev/null 2>&1; then
      COMPOSE_CMD=(podman-compose -f "$COMPOSE_FILE")
    elif podman compose -h >/dev/null 2>&1 && [ "${USE_PODMAN_NATIVE_COMPOSE:-0}" = "1" ]; then
      COMPOSE_CMD=(podman compose -f "$COMPOSE_FILE")
    fi
  fi

  if [ -z "${RUNTIME:-}" ]; then
    require docker
    RUNTIME="docker"
    COMPOSE_CMD=(docker compose -f "$COMPOSE_FILE")
  fi

  if [ ${#COMPOSE_CMD[@]} -eq 0 ]; then
    fail "No compose command found (podman compose/podman-compose/docker compose)"
  fi
}

main() {
  : >"$LOG_FILE"
  require awk
  detect_runtime

  log "Using runtime: ${RUNTIME}, compose: ${COMPOSE_CMD[*]}"

  # Best-effort cleanup of stale named containers that may conflict with compose
  local stale_names=(
    emercoin-core privateness dns-reverse-proxy pyuheprng-privatenesstools
    yggdrasil i2p-yggdrasil skywire softether-vpn ssh-gateway
  )
  for name in "${stale_names[@]}"; do
    $RUNTIME rm -f "$name" >/dev/null 2>&1 || true
  done

  log "Stopping any existing stack..."
  "${COMPOSE_CMD[@]}" down --remove-orphans >/dev/null 2>&1 || true

  log "Starting stack..."
  if [ "${COMPOSE_CMD[0]}" = "podman-compose" ]; then
    "${COMPOSE_CMD[@]}" up -d --build
  else
    "${COMPOSE_CMD[@]}" up -d --build --quiet-pull
  fi

  log "Waiting for services to stabilize (30s)..."
  sleep 30

  local required_services=(
    emercoin-core
    privateness
    dns-reverse-proxy
    pyuheprng-privatenesstools
    skywire
    ssh-gateway
    softether-vpn
  )

  local optional_services=(
    yggdrasil
    i2p-yggdrasil
  )

  wait_container_up() {
    local svc="$1"
    local retries="${2:-20}"
    local i
    for i in $(seq 1 "$retries"); do
      if $RUNTIME ps --format '{{.Names}}' | grep -qx "$svc"; then
        return 0
      fi
      sleep 1
    done
    return 1
  }

  for svc in "${required_services[@]}"; do
    if wait_container_up "$svc" 30; then
      pass "$svc container running"
    else
      fail "$svc container not running"
    fi
  done

  for svc in "${optional_services[@]}"; do
    if wait_container_up "$svc" 10; then
      pass "$svc container running"
    else
      warn "$svc container not running (optional overlay)"
    fi
  done

  log "Port reachability"
  local ports=(
    "${EMERCOIN_P2P_PORT}:Emercoin P2P"
    "${EMERCOIN_RPC_PORT}:Emercoin RPC"
    "${PRIVATENESS_RPC_PORT}:Privateness RPC"
    "${PYUHEPRNG_PORT}:pyuheprng"
    "${PRIVATENESSTOOLS_PORT}:privatenesstools"
    "${DNS_PORT}:DNS reverse proxy"
    "${SKYWIRE_PORT}:Skywire UI"
    "${YGGDRASIL_PORT}:Yggdrasil"
    "${I2P_CONSOLE_PORT}:I2P console"
    "${SOFTETHER_PORT}:SoftEther VPN"
    "${SSH_GATEWAY_PORT}:SSH gateway"
  )
  for entry in "${ports[@]}"; do
    local port=${entry%%:*}
    local label=${entry#*:}
    if command -v nc >/dev/null 2>&1 && nc -z 127.0.0.1 "$port" >/dev/null 2>&1; then
      pass "$label port $port reachable"
    else
      warn "$label port $port not reachable"
    fi
  done

  log "DNS sanity check via dns-reverse-proxy"
  if command -v dig >/dev/null 2>&1; then
    if dig @127.0.0.1 -p "$DNS_PORT" example.com +short >/dev/null 2>&1; then
      pass "dns-reverse-proxy answered queries"
    else
      warn "dns-reverse-proxy did not answer queries"
    fi
  else
    warn "dig not installed; skipping DNS check"
  fi

  log "Emercoin RPC quick check"
  if $RUNTIME exec emercoin-core emercoin-cli -datadir=/data getblockchaininfo >/dev/null 2>&1; then
    pass "Emercoin RPC responded"
  else
    warn "Emercoin RPC not ready"
  fi

  if $RUNTIME ps --format '{{.Names}}' | grep -qx 'yggdrasil'; then
    log "Yggdrasil config presence"
    if $RUNTIME exec yggdrasil test -f /etc/yggdrasil.conf >/dev/null 2>&1; then
      pass "Yggdrasil config present"
    else
      warn "Yggdrasil config missing"
    fi
  else
    warn "Yggdrasil checks skipped (container not running)"
  fi

  log "Skywire CLI status"
  local visor_status
  visor_status=$($RUNTIME exec skywire skywire-cli visor status 2>/dev/null || true)
  if [ -n "$visor_status" ]; then
    pass "Skywire CLI responded"
  else
    warn "Skywire CLI not responding"
  fi

  if $RUNTIME ps --format '{{.Names}}' | grep -qx 'i2p-yggdrasil'; then
    log "I2P console check"
    if command -v curl >/dev/null 2>&1 && curl -fsS "http://127.0.0.1:${I2P_CONSOLE_PORT}" >/dev/null 2>&1; then
      pass "I2P console reachable"
    else
      warn "I2P console not reachable"
    fi
  else
    warn "I2P checks skipped (container not running)"
  fi

  log "Container resource snapshot"
  if [ "$RUNTIME" = "podman" ]; then
    $RUNTIME stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | tee -a "$LOG_FILE" || warn "podman stats unavailable"
  else
    $RUNTIME stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | tee -a "$LOG_FILE" || warn "docker stats unavailable"
  fi

  log "E2E completed"
  echo -e "${green}All tests executed. See $LOG_FILE for details.${reset}"
}

main "$@"
