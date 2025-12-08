#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

COMPOSE_FILE="docker-compose.yml"
DOCKER_USER="nessnetwork"
PROFILE="pi3"            # pi3 | skyminer | full | mcp-server | mcp-client
DNS_MODE="hybrid"          # icann | hybrid | emerdns

# Host port used for the dns-reverse-proxy listener (matches docker-compose.yml)
DNS_PROXY_HOST_PORT="${DNS_PROXY_HOST_PORT:-1053}"

DNS_LABEL_FILE="$SCRIPT_DIR/.dns_mode_labels"
DNS_LABEL_ICANN="ICANN-only (deny EmerDNS)"
DNS_LABEL_HYBRID="Hybrid (EmerDNS first, ICANN fallback)"
DNS_LABEL_EMERDNS="EmerDNS-only (deny ICANN)"

# Service bundles per profile (adjust as services become available)
PI3_SERVICES=(
  emercoin-core
  privateness
  skywire
  dns-reverse-proxy
  pyuheprng-privatenesstools
)

# Skyminer profile: Pi3 essentials without the Skywire container
SKYMINER_SERVICES=(
  emercoin-core
  privateness
  dns-reverse-proxy
  pyuheprng-privatenesstools
)

MCP_SERVER_SERVICES=(
  emercoin-mcp-server
  privateness-mcp-server
  magic-wormhole-rendezvous
  magic-wormhole-transit
)

MCP_CLIENT_SERVICES=(
  emercoin-mcp-app
  privateness-mcp-app
  magic-wormhole-client
)

cyan="\033[1;36m"
magenta="\033[1;35m"
yellow="\033[1;33m"
green="\033[1;32m"
red="\033[1;31m"

# NESS dark theme palette (foreground-only so background stays deep charcoal)
primary="\033[38;5;45m"
accent="\033[38;5;208m"
muted="\033[38;5;244m"
panel_fg="\033[38;5;252m"
panel_border="\033[38;5;239m"
panel_bg="\033[48;5;233m"
title_glow="\033[38;5;213m"
reset="\033[0m"

check_ok_symbol="[  OK  ]"
check_fail_symbol="[ FAIL ]"

load_dns_labels() {
  if [ -f "$DNS_LABEL_FILE" ]; then
    while IFS='=' read -r key value; do
      value=${value%$'\r'}
      case "$key" in
        icann) DNS_LABEL_ICANN="$value" ;;
        hybrid) DNS_LABEL_HYBRID="$value" ;;
        emerdns) DNS_LABEL_EMERDNS="$value" ;;
      esac
    done < "$DNS_LABEL_FILE"
  fi
}

save_dns_labels() {
  cat > "$DNS_LABEL_FILE" <<EOF
icann=$DNS_LABEL_ICANN
hybrid=$DNS_LABEL_HYBRID
emerdns=$DNS_LABEL_EMERDNS
EOF
}

apply_dns_mode() {
  case "$DNS_MODE" in
    icann)
      DNS_DESC="$DNS_LABEL_ICANN"
      DNS_SERVERS="1.1.1.1 8.8.8.8"
      ;;
    emerdns)
      DNS_DESC="$DNS_LABEL_EMERDNS"
      DNS_SERVERS="127.0.0.1"
      ;;
    *)
      DNS_MODE="hybrid"
      DNS_DESC="$DNS_LABEL_HYBRID"
      DNS_SERVERS="127.0.0.1 1.1.1.1"
      ;;
  esac
  export DNS_MODE DNS_DESC DNS_SERVERS
}

select_dns_mode() {
  echo
  echo -e "${green}Select Reality / DNS Mode:${reset}"
  echo "  0) ${DNS_LABEL_ICANN}"
  echo "  1) ${DNS_LABEL_HYBRID}"
  echo "  2) ${DNS_LABEL_EMERDNS}"
  echo
  read -rp "Select DNS mode [0-2]: " d_choice
  case "$d_choice" in
    0) DNS_MODE="icann" ;;
    1) DNS_MODE="hybrid" ;;
    2) DNS_MODE="emerdns" ;;
    *) echo "Invalid choice, keeping current: $DNS_MODE" ;;
  esac
  apply_dns_mode
  echo -e "${yellow}DNS mode set to: ${DNS_MODE} (${DNS_DESC})${reset}"
}

edit_dns_mode_labels() {
  echo
  echo -e "${green}Customize Reality / DNS Mode Names:${reset}"
  read -rp "Label for ICANN-only [${DNS_LABEL_ICANN}]: " input
  if [ -n "$input" ]; then DNS_LABEL_ICANN="$input"; fi
  read -rp "Label for Hybrid [${DNS_LABEL_HYBRID}]: " input
  if [ -n "$input" ]; then DNS_LABEL_HYBRID="$input"; fi
  read -rp "Label for EmerDNS-only [${DNS_LABEL_EMERDNS}]: " input
  if [ -n "$input" ]; then DNS_LABEL_EMERDNS="$input"; fi
  save_dns_labels
  apply_dns_mode
  echo -e "${yellow}Reality mode labels updated.${reset}"
}

profile_label() {
  case "$1" in
    pi3) echo "Pi 3 Essentials" ;;
    skyminer) echo "Skyminer (no Skywire container)" ;;
    full) echo "Full Node" ;;
    mcp-server) echo "MCP Server Suite" ;;
    mcp-client) echo "MCP Client Suite" ;;
    *) echo "$1" ;;
  esac
}

select_profile() {
  echo
  echo -e "${green}Select Deployment Profile:${reset}"
  echo "  1) Pi 3 Essentials (Emercoin, Privateness, DNS, Skywire, Tools)"
  echo "  2) Skyminer (Emercoin, Privateness, DNS, Tools — no Skywire container)"
  echo "  3) Full Node (Emercoin, Yggdrasil, I2P-Yggdrasil, Skywire, AmneziaWG, Skywire-AmneziaWG, DNS, pyuheprng, Privateness, Privatenesstools)"
  echo "  4) MCP Server Suite (MCP daemons, wormhole rendezvous)"
  echo "  5) MCP Client Suite (apps, QR helpers, wormhole client)"
  echo
  read -rp "Select profile [1-5]: " p_choice
  case "$p_choice" in
    1) PROFILE="pi3" ;;
    2) PROFILE="skyminer" ;;
    3) PROFILE="full" ;;
    4) PROFILE="mcp-server" ;;
    5) PROFILE="mcp-client" ;;
    *) echo "Invalid choice, keeping current: $(profile_label "$PROFILE")" ;;
  esac
  echo -e "${yellow}Profile set to: $(profile_label "$PROFILE")${reset}"
}

require_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo -e "${red}Docker is required but not installed.${reset}"
    return 1
  fi
  return 0
}

compose() {
  docker compose -f "$COMPOSE_FILE" "$@"
}

ensure_stack_stopped() {
  require_docker || return 1
  # If any containers exist for this compose project, stop them cleanly first
  if compose ps -q | grep -q .; then
    echo -e "${yellow}Existing Ness stack detected, stopping before restart...${reset}"
    compose down
  fi
}

cleanup_dns_reverse_proxy() {
  require_docker || return 1
  # If a stray dns-reverse-proxy container exists (from another project/run), stop and remove it
  if docker ps -a --format '{{.Names}}' | grep -q '^dns-reverse-proxy$'; then
    echo -e "${yellow}Found existing dns-reverse-proxy container, stopping to free UDP/53...${reset}"
    docker stop dns-reverse-proxy >/dev/null 2>&1 || true
    docker rm -f dns-reverse-proxy >/dev/null 2>&1 || true
  fi
}

is_port53_busy() {
  local hits=""
  if command -v ss >/dev/null 2>&1; then
    hits=$(ss -tulnp 2>/dev/null | grep -E ":${DNS_PROXY_HOST_PORT}$")
  elif command -v netstat >/dev/null 2>&1; then
    hits=$(netstat -an 2>/dev/null | grep -E ":${DNS_PROXY_HOST_PORT}$")
  fi

  if [ -n "$hits" ]; then
    echo -e "${yellow}Port ${DNS_PROXY_HOST_PORT} is already in use by:${reset}"
    echo "$hits"
    return 0
  fi

  return 1
}

check_port53_free() {
  # Best-effort: if ss or netstat are present, report if the DNS listener port is still bound
  if command -v ss >/dev/null 2>&1; then
    if ss -uln 2>/dev/null | awk '{print $5}' | grep -q ":${DNS_PROXY_HOST_PORT}$"; then
      echo -e "${yellow}Warning:${reset} UDP ${DNS_PROXY_HOST_PORT} still in use after shutdown (non-Docker or external listener)."
    fi
    if ss -tln 2>/dev/null | awk '{print $5}' | grep -q ":${DNS_PROXY_HOST_PORT}$"; then
      echo -e "${yellow}Warning:${reset} TCP ${DNS_PROXY_HOST_PORT} still in use after shutdown (non-Docker or external listener)."
    fi
  elif command -v netstat >/dev/null 2>&1; then
    if netstat -anu 2>/dev/null | awk '{print $4}' | grep -q ":${DNS_PROXY_HOST_PORT}$"; then
      echo -e "${yellow}Warning:${reset} UDP ${DNS_PROXY_HOST_PORT} still in use after shutdown (non-Docker or external listener)."
    fi
    if netstat -ant 2>/dev/null | awk '{print $4}' | grep -q ":${DNS_PROXY_HOST_PORT}$"; then
      echo -e "${yellow}Warning:${reset} TCP ${DNS_PROXY_HOST_PORT} still in use after shutdown (non-Docker or external listener)."
    fi
  fi
}

compose_up_services() {
  local services=("$@")
  if [ ${#services[@]} -eq 0 ]; then
    echo "No services defined for this profile yet."
    return 1
  fi
  compose up -d "${services[@]}"
}

service_status() {
  local svc="$1"

  if ! command -v docker >/dev/null 2>&1; then
    echo "UNKNOWN"
    return 0
  fi

  if docker ps --format '{{.Names}}' | grep -q "^${svc}$"; then
    echo "RUNNING"
  elif docker ps -a --format '{{.Names}}' | grep -q "^${svc}$"; then
    echo "STOPPED"
  else
    echo "NOT PRESENT"
  fi
}

start_single_service() {
  local svc="$1"
  local label="$2"

  echo
  echo -e "${yellow}Starting service: ${label}...${reset}"
  require_docker || return 1

  compose up -d "$svc"

  if [ "$svc" = "emercoin-core" ]; then
    wait_for_emercoin_core || true
  fi
}

stop_single_service() {
  local svc="$1"
  local label="$2"

  echo
  echo -e "${yellow}Stopping service: ${label}...${reset}"
  require_docker || return 1

  compose stop "$svc" >/dev/null 2>&1 || true
}

wait_for_emercoin_core() {
  if ! docker ps --format '{{.Names}}' | grep -q '^emercoin-core$'; then
    return 0
  fi
  local headstart=${EMC_HEADSTART:-45}
  local max_tries=${EMC_MAX_TRIES:-90}
  echo "Waiting for emercoin-core (emercoin-cli getblockchaininfo) to answer..."
  # Give emercoind a head start on first boot
  sleep "$headstart"
  # Then up to ~2 minutes (60 * 2s) for slow first-start / sync
  local i
  for ((i=1; i<=max_tries; i++)); do
    if MSYS_NO_PATHCONV=1 docker exec emercoin-core emercoin-cli -datadir=/data getblockchaininfo >/dev/null 2>&1; then
      echo "emercoin-core CLI is answering."
      return 0
    fi
    sleep 2
  done
  echo "emercoin-core CLI did not respond within timeout (continuing)."
}

start_stack() {
  echo
  echo -e "${yellow}Starting Ness stack (Profile: $(profile_label "$PROFILE"))...${reset}"
  require_docker || return 1

  # Always start from a clean slate for this compose project
  ensure_stack_stopped || return 1

   # Also ensure no leftover dns-reverse-proxy container is still binding UDP/53
   cleanup_dns_reverse_proxy || true

   # Hard-fail if the DNS listener port is already taken by something we don't control
   if is_port53_busy; then
     echo -e "${red}Cannot start stack:${reset} port ${DNS_PROXY_HOST_PORT} (TCP/UDP) is already in use on the host."
     echo -e "${yellow}Hint:${reset} check for local DNS services or previous runs holding :${DNS_PROXY_HOST_PORT}."
     return 1
   fi

  case "$PROFILE" in
    pi3)
      # Start Emercoin core first, wait for real RPC answers, then bring up the rest
      compose_up_services emercoin-core || return 1
      wait_for_emercoin_core || true
      compose_up_services privateness dns-reverse-proxy pyuheprng-privatenesstools || return 1
      ;;
    skyminer)
      # Skyminer: same as Pi3 but without the Skywire container
      compose_up_services emercoin-core || return 1
      wait_for_emercoin_core || true
      compose_up_services privateness dns-reverse-proxy pyuheprng-privatenesstools || return 1
      ;;
    full)
      # For full node, still prefer Emercoin RPC readiness before the rest
      compose up -d emercoin-core || return 1
      wait_for_emercoin_core || true
      compose up -d || return 1
      ;;
    mcp-server)
      compose_up_services "${MCP_SERVER_SERVICES[@]}" || return 1
      ;;
    mcp-client)
      compose_up_services "${MCP_CLIENT_SERVICES[@]}" || return 1
      ;;
    *)
      echo "Unknown profile: $PROFILE"
      return 1
      ;;
  esac
}

stack_status() {
  require_docker || return 1
  echo
  echo -e "${yellow}docker compose ps:${reset}"
  compose ps || true

  echo
  echo -e "${green}Key service statuses:${reset}"
  local svc label status color
  local pairs=(
    "emercoin-core:Emercoin Core"
    "privateness:Privateness"
    "pyuheprng-privatenesstools:pyuheprng-privatenesstools"
    "dns-reverse-proxy:DNS reverse proxy"
    "skywire:Skywire"
    "yggdrasil:Yggdrasil"
    "i2p-yggdrasil:I2P-Yggdrasil"
    "amneziawg:AmneziaWG"
    "skywire-amneziawg:Skywire-AmneziaWG"
  )

  local pair
  for pair in "${pairs[@]}"; do
    svc=${pair%%:*}
    label=${pair#*:}
    status=$(service_status "$svc")
    case "$status" in
      RUNNING) color="$green" ;;
      STOPPED) color="$red" ;;
      *)       color="$yellow" ;;
    esac
    printf "  %-24s %b%s%b\n" "$label" "$color" "$status" "$reset"
  done
}

logs_stack() {
  require_docker || return 1
  compose logs -f
}

remove_everything_local() {
  require_docker || return 1
  echo -e "${yellow}Stopping all running Docker containers...${reset}"
  docker ps -aq | xargs -r docker stop
  echo -e "${yellow}Removing all Docker containers...${reset}"
  docker ps -aq | xargs -r docker rm -f
  echo -e "${yellow}Pruning Docker data (images, cache, volumes)...${reset}"
  docker system prune -af --volumes
  echo -e "${green}Docker cleanup complete.${reset}"
}

context_size() {
  local path="$1"
  if command -v du >/dev/null 2>&1; then
    du -sh "$path" 2>/dev/null | awk '{print $1}'
  else
    echo "?"
  fi
}

build_single_image() {
  echo
  local images=(
    "emercoin-core"
    "yggdrasil"
    "dns-reverse-proxy"
    "skywire"
    "privateness"
    "ness-blockchain"
    "pyuheprng"
    "privatenesstools"
    "pyuheprng-privatenesstools"
    "ipfs"
    "i2p-yggdrasil"
    "amneziawg"
    "skywire-amneziawg"
    "amnezia-exit"
    "ness-unified"
  )

  echo -e "${green}Build single image (with context size hints):${reset}"
  local idx=1
  for img in "${images[@]}"; do
    local size
    size=$(context_size "${SCRIPT_DIR}/${img}")
    echo "  ${idx}) ${img} (context ~${size})"
    idx=$((idx+1))
  done
  echo "  0) Back"
  echo
  read -rp "Select an image: " choice

  if [ "$choice" = "0" ]; then
    return 0
  fi

  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#images[@]}" ]; then
    echo "Invalid choice."
    return 1
  fi

  local image="${images[$((choice-1))]}"
  require_docker || return 1

  local context_path="${SCRIPT_DIR}/${image}"
  if [ ! -d "$context_path" ]; then
    echo "Build context not found: $context_path"
    return 1
  fi

  local docker_user="${DOCKER_USER:-nessnetwork}"
  echo
  echo -e "${yellow}Building ${docker_user}/${image}:latest...${reset}"
  docker build -t "${docker_user}/${image}:latest" "$context_path"
}

build_images_menu() {
  echo
  echo -e "${green}Build Images:${reset}"
  echo "  1) build-all.sh (all images)"
  echo "  2) build-multiarch.sh (multi-arch, pushes to registry)"
  echo "  3) Build single image (with context size hints)"
  echo "  0) Back"
  echo
  read -rp "Select option: " b_choice
  case "$b_choice" in
    1) ./build-all.sh ;;
    2) ./build-multiarch.sh ;;
    3) build_single_image ;;
    0) return 0 ;;
    *) echo "Invalid option." ;;
  esac
}

service_control_menu() {
  local svc="$1"
  local label="$2"
  while true; do
    echo
    echo -e "${green}Service: ${label} (${svc})${reset}"
    local status color
    status=$(service_status "$svc")
    case "$status" in
      RUNNING) color="$green" ;;
      STOPPED) color="$red" ;;
      *) color="$yellow" ;;
    esac
    echo -e "  Status: ${color}${status}${reset}"
    echo "  1) Start"
    echo "  2) Stop"
    echo "  0) Back"
    echo
    read -rp "Select option: " c
    case "$c" in
      1) start_single_service "$svc" "$label" ;;
      2) stop_single_service "$svc" "$label" ;;
      0) return 0 ;;
      *) echo "Invalid choice." ;;
    esac
  done
}

services_menu() {
  while true; do
    echo
    echo -e "${green}Individual services control:${reset}"
    echo "  1) Emercoin Core"
    echo "  2) Privateness"
    echo "  3) Skywire"
    echo "  4) DNS reverse proxy"
    echo "  5) pyuheprng-privatenesstools"
    echo "  6) Yggdrasil"
    echo "  7) I2P-Yggdrasil"
    echo "  8) AmneziaWG"
    echo "  9) Skywire-AmneziaWG"
    echo "  0) Back"
    echo
    read -rp "Select service: " choice
    case "$choice" in
      1) service_control_menu "emercoin-core" "Emercoin Core" ;;
      2) service_control_menu "privateness" "Privateness" ;;
      3) service_control_menu "skywire" "Skywire" ;;
      4) service_control_menu "dns-reverse-proxy" "DNS reverse proxy" ;;
      5) service_control_menu "pyuheprng-privatenesstools" "pyuheprng-privatenesstools" ;;
      6) service_control_menu "yggdrasil" "Yggdrasil" ;;
      7) service_control_menu "i2p-yggdrasil" "I2P-Yggdrasil" ;;
      8) service_control_menu "amneziawg" "AmneziaWG" ;;
      9) service_control_menu "skywire-amneziawg" "Skywire-AmneziaWG" ;;
      0) return 0 ;;
      *) echo "Invalid choice." ;;
    esac
  done
}

stack_menu() {
  echo
  echo -e "${green}Stack Control:${reset}"
  echo "  1) Start stack"
  echo "  2) Stop stack"
   echo "  3) Individual services"
  echo "  0) Back"
  echo
  read -rp "Select option: " s_choice
  case "$s_choice" in
    1) start_stack ;;
    2) compose down; cleanup_dns_reverse_proxy || true; check_port53_free ;;
    3) services_menu ;;
    0) return 0 ;;
    *) echo "Invalid option." ;;
  esac
 }

check_entropy() {
  echo -e "${yellow}Entropy check placeholder:${reset} ensure UHE 1536-bit generators are active (RC4OK + UHEPRNG)."
}

ping_host() {
  local host="$1"
  if ping -c 1 127.0.0.1 >/dev/null 2>&1; then
    ping -c 2 "$host"
  else
    ping -n 2 "$host"
  fi
}

check_tcp_port() {
  local host="$1" port="$2" label="$3"
  echo "-- Checking TCP ${host}:${port} (${label})"
  if command -v nc >/dev/null 2>&1; then
    if nc -z "$host" "$port" >/dev/null 2>&1; then
      echo -e " ${green}${check_ok_symbol}${reset} ${label} reachable on ${host}:${port}"
      return 0
    fi
  elif ( : < /dev/tcp/127.0.0.1/1 ) 2>/dev/null; then
    if : < /dev/tcp/$host/$port 2>/dev/null; then
      echo -e " ${green}${check_ok_symbol}${reset} ${label} reachable on ${host}:${port}"
      return 0
    fi
  else
    if curl -s --max-time 3 "http://${host}:${port}" >/dev/null 2>&1; then
      echo -e " ${green}${check_ok_symbol}${reset} ${label} HTTP reachable on ${host}:${port}"
      return 0
    fi
  fi
  echo -e " ${red}${check_fail_symbol}${reset} ${label} NOT reachable on ${host}:${port}"
  return 1
}

test_pyuheprng() {
  echo
  echo -e "${yellow}Testing pyuheprng HTTP health (port 5000)...${reset}"
  # Prefer an in-container check to avoid host TCP quirks on Windows
  if docker ps --format '{{.Names}}' | grep -q '^pyuheprng-privatenesstools$'; then
    if MSYS_NO_PATHCONV=1 docker exec pyuheprng-privatenesstools bash -lc \
        'curl -s --max-time 5 "http://127.0.0.1:5000/health" >/dev/null 2>&1'; then
      echo -e " ${green}${check_ok_symbol}${reset} /health responding on 5000 (in-container)"
      return 0
    fi
  fi

  # Fallback: try from the host side (mapped port 5000)
  echo -e " ${yellow}No in-container /health detected, falling back to host TCP probe...${reset}"
  check_tcp_port 127.0.0.1 5000 "pyuheprng"
}

test_privatenesstools() {
  echo
  echo -e "${yellow}Testing privatenesstools HTTP (port 8888)...${reset}"
  if curl -s --max-time 5 "http://127.0.0.1:8888/health" >/dev/null 2>&1; then
    echo -e " ${green}${check_ok_symbol}${reset} /health responding on 8888"
  else
    echo -e " ${yellow}No /health endpoint detectable, falling back to TCP probe...${reset}"
    check_tcp_port 127.0.0.1 8888 "privatenesstools"
  fi
}

test_dns_reverse_proxy() {
  echo
  echo -e "${yellow}Testing dns-reverse-proxy listener (ports ${DNS_PROXY_HOST_PORT} and 8053)...${reset}"
  check_tcp_port 127.0.0.1 "${DNS_PROXY_HOST_PORT}" "dns-reverse-proxy (DNS)" || true
  check_tcp_port 127.0.0.1 8053 "dns-reverse-proxy (control/API)" || true
}

test_skywire() {
  echo
  echo -e "${yellow}Testing Skywire visor HTTP (port 8000)...${reset}"
  check_tcp_port 127.0.0.1 8000 "Skywire visor"
}

health_check() {
  echo
  echo -e "${yellow}Core node health check...${reset}"
  require_docker || return 1

  local overall_rc=0
  local rpc_rc=0

  echo
  echo "== Docker services (Ness stack) =="
  compose ps
  local rc_ps=$?
  if [ "$rc_ps" -eq 0 ]; then
    echo -e " ${green}${check_ok_symbol}${reset} Docker stack reachable"
  else
    echo -e " ${red}${check_fail_symbol}${reset} Docker stack reachable"
    overall_rc=1
  fi

  echo
  echo "== Privateness JSON-RPC (via privateness-cli / port 6660) =="
  local priv_rpc_out priv_rpc_rc
  priv_rpc_rc=0
  if [ -x "${SCRIPT_DIR}/privateness-cli" ]; then
    priv_rpc_out=$("${SCRIPT_DIR}/privateness-cli" status 2>&1) || priv_rpc_rc=$?
  else
    priv_rpc_out=$(docker exec privateness privateness-cli status 2>&1) || priv_rpc_rc=$?
  fi

  if [ "$priv_rpc_rc" -eq 0 ] && echo "$priv_rpc_out" | grep -q '"seq"'; then
    echo "$priv_rpc_out" | grep -E 'seq|block_hash' || echo "$priv_rpc_out" | head -c 200
    echo
    echo -e " ${green}${check_ok_symbol}${reset} Privateness JSON-RPC responding via privateness-cli"
  else
    echo "$priv_rpc_out" | head -c 200; echo
    echo -e " ${red}${check_fail_symbol}${reset} Privateness JSON-RPC check failed via privateness-cli"
    rpc_rc=1
  fi

  echo
  echo "== Privateness vs explorer (seq/block_hash) =="
  local explorer_health local_status
  explorer_health=$(curl -s https://ness-explorer.magnetosphere.net/api/health 2>/dev/null || true)

  if [ -x "${SCRIPT_DIR}/privateness-cli" ]; then
    local_status=$("${SCRIPT_DIR}/privateness-cli" status 2>/dev/null || true)
  else
    local_status=$(docker exec privateness privateness-cli status 2>/dev/null || true)
  fi

  if [ -n "$explorer_health" ] && [ -n "$local_status" ]; then
    echo "-- Explorer:"
    echo "$explorer_health" | grep -E 'seq|block_hash' || true
    echo
    echo "-- Local (privateness-cli status):"
    echo "$local_status" | grep -E 'seq|block_hash' || true

    local exp_seq loc_seq exp_hash loc_hash
    # Use more tolerant patterns that allow whitespace around the colon, e.g. "block_hash": "..."
    exp_seq=$(echo "$explorer_health" | grep -m1 '"seq"' | tr -dc '0-9')
    loc_seq=$(echo "$local_status"   | grep -m1 '"seq"' | tr -dc '0-9')
    exp_hash=$(echo "$explorer_health" | grep -m1 '"block_hash"' | sed 's/.*"block_hash"[[:space:]]*:[[:space:]]*"//;s/".*//' | tr -d ' \r\n\t' | tr '[:upper:]' '[:lower:]')
    loc_hash=$(echo "$local_status"   | grep -m1 '"block_hash"' | sed 's/.*"block_hash"[[:space:]]*:[[:space:]]*"//;s/".*//' | tr -d ' \r\n\t' | tr '[:upper:]' '[:lower:]')

    if [ -n "$exp_seq" ] && [ -n "$loc_seq" ] && [ "$exp_seq" = "$loc_seq" ] && \
       [ -n "$exp_hash" ] && [ -n "$loc_hash" ] && [ "$exp_hash" = "$loc_hash" ]; then
      echo -e " ${green}${check_ok_symbol}${reset} Privateness seq/hash match explorer"
    else
      echo -e " ${red}${check_fail_symbol}${reset} Privateness seq/hash MISMATCH explorer"
      overall_rc=1
    fi
  else
    echo "Could not obtain explorer or local Privateness status."
    echo -e " ${red}${check_fail_symbol}${reset} Privateness vs explorer check failed"
    overall_rc=1
  fi

  echo
  echo "== Emercoin JSON-RPC (via emercoin-cli in container) =="
  local emc_rpc=""
  if docker ps --format '{{.Names}}' | grep -q '^emercoin-core$'; then
    emc_rpc=$(MSYS_NO_PATHCONV=1 docker exec emercoin-core emercoin-cli -datadir=/data getblockchaininfo 2>/dev/null || true)
  fi

  if echo "$emc_rpc" | grep -q '"blocks"'; then
    echo "$emc_rpc" | tr '\n' ' ' | sed 's/  */ /g' | head -c 200; echo
    echo -e " ${green}${check_ok_symbol}${reset} Emercoin JSON-RPC responding via emercoin-cli"
  else
    echo "$emc_rpc" | head -c 200; echo
    echo -e " ${red}${check_fail_symbol}${reset} Emercoin JSON-RPC failed via emercoin-cli"
    rpc_rc=1
  fi

  echo
  echo "== Emercoin vs explorer =="
  local emc_height_raw emc_hash_remote
  emc_height_raw=$(curl -s -H 'Accept: application/json' https://explorer.emercoin.com/api/stats/block_height 2>/dev/null || true)
  emc_hash_remote=$(curl -s -H 'Accept: application/json' https://explorer.emercoin.com/api/block/latest 2>/dev/null || true)

  if [ -n "$emc_height_raw" ] && echo "$emc_rpc" | grep -q '"blocks"'; then
    echo "-- Explorer height (raw, truncated):"
    echo "$emc_height_raw" | head -c 200 || true
    echo
    echo "-- Local getblockchaininfo (blocks):"
    echo "$emc_rpc" | awk -F: '/"blocks"/ {print $0; exit}' || true

    local remote_height local_height
    if echo "$emc_height_raw" | grep -qi '<html'; then
      remote_height=""
    else
      remote_height=$(echo "$emc_height_raw" | sed -n 's/.*"block_height"[[:space:]]*:[[:space:]]*"\([0-9][0-9]*\)".*/\1/p' | head -n1)
      if [ -z "$remote_height" ]; then
        remote_height=$(echo "$emc_height_raw" | tr -dc '0-9' | head -c 18)
      fi
    fi
    local_height=$(echo "$emc_rpc" | awk -F: '/"blocks"/ {gsub(/[^0-9]/, "", $2); print $2; exit}')

    echo
    echo "-- Explorer latest block hash:"
    echo "$emc_hash_remote" | grep -E '"block(hash|_hash)"[[:space:]]*:[[:space:]]*"[^"]*"' || true
    echo
    echo "-- Local best block hash (emercoin-cli getbestblockhash):"

    local emc_hash_local
    emc_hash_local=$(MSYS_NO_PATHCONV=1 docker exec emercoin-core emercoin-cli -datadir=/data getbestblockhash 2>/dev/null || true)

    echo "$emc_hash_local" | head -c 200; echo

    local remote_hash local_hash
    remote_hash=$(echo "$emc_hash_remote" | sed -n 's/.*"blockhash"[[:space:]]*:[[:space:]]*"\([^" ]*\)".*/\1/p; s/.*"block_hash"[[:space:]]*:[[:space:]]*"\([^" ]*\)".*/\1/p' | head -n1 | tr -d ' \r\n\t' | tr '[:upper:]' '[:lower:]')
    local_hash=$(echo "$emc_hash_local" | tr -d ' \r\n\t' | tr '[:upper:]' '[:lower:]' | head -c 128)

    if [ -n "$remote_height" ] && [ -n "$local_height" ] && [ "$remote_height" = "$local_height" ]; then
      if [ -n "$remote_hash" ] && [ -n "$local_hash" ]; then
        if [ "$remote_hash" = "$local_hash" ]; then
          echo -e " ${green}${check_ok_symbol}${reset} Emercoin height/hash match explorer"
        else
          echo -e " ${red}${check_fail_symbol}${reset} Emercoin hash MISMATCH explorer (heights match)"
          overall_rc=1
        fi
      else
        echo -e " ${yellow}${check_ok_symbol}${reset} Emercoin explorer hash missing, but heights match (hash not checked)"
      fi
    else
      echo -e " ${red}${check_fail_symbol}${reset} Emercoin height MISMATCH explorer"
      overall_rc=1
    fi
  else
    echo "Could not obtain explorer or local Emercoin info."
    echo -e " ${red}${check_fail_symbol}${reset} Emercoin vs explorer check failed"
    overall_rc=1
  fi

  echo
  echo "== DNS reverse proxy (tier 1) =="
  local dns_rc=0
  if docker ps --format '{{.Names}}' | grep -q '^dns-reverse-proxy$'; then
    check_tcp_port 127.0.0.1 "${DNS_PROXY_HOST_PORT}" "dns-reverse-proxy (DNS)" || dns_rc=1
    check_tcp_port 127.0.0.1 8053 "dns-reverse-proxy (control/API)" || dns_rc=1
  else
    echo -e " ${red}${check_fail_symbol}${reset} dns-reverse-proxy container not running"
    dns_rc=1
  fi
  if [ "$dns_rc" -ne 0 ]; then
    overall_rc=1
  fi

  echo
  echo "== Tier 1 entropy (pyuheprng) =="
  test_pyuheprng || overall_rc=1

  if [ "$rpc_rc" -ne 0 ]; then
    overall_rc=1
  fi

  echo
  if [ "$overall_rc" -eq 0 ]; then
    echo -e "${green}===== GLOBAL STATUS: SUCCESS (RPC + explorer) =====${reset}"
  else
    echo -e "${red}===== GLOBAL STATUS: FAILED (RPC + explorer) =====${reset}"
  fi
}

test_menu() {
  while true; do
    echo
    echo -e "${green}Test / Status menu:${reset}"
    echo "  1) Core node health check"
    echo "  2) Entropy check"
    echo "  3) Test pyuheprng (port 5000)"
    echo "  4) Test dns-reverse-proxy (ports ${DNS_PROXY_HOST_PORT}/8053)"
    echo "  5) Test Skywire visor (port 8000)"
    echo "  0) Back"
    echo
    read -rp "Select an option: " choice
    case "$choice" in
      1) health_check ;;
      2) check_entropy ;;
      3) test_pyuheprng ;;
      4) test_dns_reverse_proxy ;;
      5) test_skywire ;;
      0) return 0 ;;
      *) echo "Invalid choice." ;;
    esac
  done
}

print_info() {
  echo -e "${panel_bg}${title_glow}"
  logo 2>/dev/null || true
  echo -e "${reset}"

  local host os kernel uptime cpu mem disk docker_status stack
  host=$(hostname 2>/dev/null || echo "?")
  if [ -r /etc/os-release ]; then
    os=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2- | tr -d '"')
  else
    os=$(uname -s 2>/dev/null || echo "?")
  fi
  kernel=$(uname -r 2>/dev/null || echo "?")
  uptime=$(uptime -p 2>/dev/null || echo "?")
  cpu=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^[ \t]*//' || echo "?")
  mem=$(free -h 2>/dev/null | awk '/Mem:/ {print $3 "/" $2}' || echo "?")
  disk=$(df -h / 2>/dev/null || echo "?")

  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    docker_status="running"
  elif command -v docker >/dev/null 2>&1; then
    docker_status="installed (daemon not running)"
  else
    docker_status="not installed"
  fi

  local box_top="${panel_bg}${panel_border}┌────────────────────────────────────────────┐${reset}"
  local box_mid="${panel_bg}${panel_border}├────────────────────────────────────────────┤${reset}"
  local box_bottom="${panel_bg}${panel_border}└────────────────────────────────────────────┘${reset}"

  echo -e "$box_top"
  printf "%b│ %b%-15s%b %s%b\n" "$panel_bg" "$muted" "Host" "$panel_fg" "$host" "$reset"
  printf "%b│ %b%-15s%b %s%b\n" "$panel_bg" "$muted" "OS" "$panel_fg" "$os" "$reset"
  printf "%b│ %b%-15s%b %s%b\n" "$panel_bg" "$muted" "Kernel" "$panel_fg" "$kernel" "$reset"
  printf "%b│ %b%-15s%b %s%b\n" "$panel_bg" "$muted" "Uptime" "$panel_fg" "$uptime" "$reset"
  printf "%b│ %b%-15s%b %s%b\n" "$panel_bg" "$muted" "CPU" "$panel_fg" "${cpu:-"?"}" "$reset"
  printf "%b│ %b%-15s%b %s%b\n" "$panel_bg" "$muted" "Memory" "$panel_fg" "$mem" "$reset"
  printf "%b│ %b%-15s%b %s%b\n" "$panel_bg" "$muted" "Disk (/)" "$panel_fg" "$disk" "$reset"
  printf "%b│ %b%-15s%b %s%b\n" "$panel_bg" "$muted" "Docker" "$panel_fg" "$docker_status" "$reset"
  echo -e "$box_mid"
  printf "%b│ %b%-15s%b %s%b\n" "$panel_bg" "$muted" "Reality" "$accent" "$DNS_MODE → $DNS_DESC" "$reset"
  printf "%b│ %b%-15s%b %s%b\n" "$panel_bg" "$muted" "Profile" "$primary" "$(profile_label "$PROFILE")" "$reset"
  printf "%b│ %b%-15s%b %s%b\n" "$panel_bg" "$muted" "Docker User" "$panel_fg" "$DOCKER_USER" "$reset"
  echo -e "$box_bottom"
}

logo() {
  local lines=(
"    /\\        _                "
"   /  \\  __ _| |_ _ __ _   _   "
"  / /\\ \\/ _' | __| '__| | | |  "
" / ____ \\ (_| | |_| |  | |_| | "
"\_/_    \\_\\__,_|\\__|_|   \\__,_| "
  )
  for line in "${lines[@]}"; do
    echo "$line"
  done
}

menu() {
  while true; do
    clear
    print_info
    echo
    echo -e "${panel_bg}${panel_border}╔══════════════════╦═══════════════════════════════╗${reset}"
    printf "%b║ %bMenu V3%b          ║ %bReality:%b %s → %s%b\n" "$panel_bg" "$primary" "$panel_border" "$muted" "$accent" "$DNS_MODE" "$DNS_DESC" "$reset"
    echo -e "${panel_bg}${panel_border}╠══════════════════╩═══════════════════════════════╣${reset}"

    local menu_items=(
      "${accent}[0]${reset} Reality / DNS Mode"
      "${accent}[1]${reset} Select Profile"
      "${accent}[2]${reset} Build images"
      "${accent}[3]${reset} Start/stop stack"
      "${accent}[4]${reset} Show stack status"
      "${accent}[5]${reset} Tail stack logs"
      "${accent}[6]${reset} Test / Status menu"
      "${accent}[7]${reset} Remove everything local"
      "${accent}[8]${reset} Rename Reality Modes"
      "${accent}[9]${reset} Exit"
    )
    for item in "${menu_items[@]}"; do
      echo -e "${panel_bg}${panel_fg}  ${item}${reset}"
    done
    echo -e "${panel_bg}${panel_border}╚═══════════════════════════════════════════════════╝${reset}"

    echo
    read -rp "Select an option: " choice
    case "$choice" in
      0) select_dns_mode ;;
      1) select_profile ;;
      2) build_images_menu ;;
      3) stack_menu ;;
      4) stack_status ;;
      5) logs_stack ;;
      6) test_menu ;;
      7) remove_everything_local ;;
      8) edit_dns_mode_labels ;;
      9) exit 0 ;;
      *) echo "Invalid choice." ;;
    esac
    echo
    read -rp "Press Enter to continue..." _pause
  done
}

load_dns_labels
apply_dns_mode
menu
