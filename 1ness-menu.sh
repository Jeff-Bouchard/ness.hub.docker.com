#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

COMPOSE_FILE="docker-compose.ness.yml"

cyan="\033[1;36m"
magenta="\033[1;35m"
yellow="\033[1;33m"
green="\033[1;32m"
red="\033[1;31m"
reset="\033[0m"

check_ok_symbol="✔"
check_fail_symbol="✘"

logo() {
  cat <<'EOF'

  ___       _                        ______     _ _        _____ _____ _____   _____ _             _    
 / _ \     | |                       |  ___|   | | |      |  _  /  ___|_   _| /  ___| |           | |   
/ /_\ \ ___| |_ __ _ _ __ _   _ ___  | |_ _   _| | |______| | | \ `--.  | |   \ `--.| |_ __ _  ___| | __
|  _  |/ __| __/ _` | '__| | | / __| |  _| | | | | |______| | | |`--. \ | |    `--. \ __/ _` |/ __| |/ /
| | | | (__| || (_| | |  | |_| \__ \ | | | |_| | | |      \ \_/ /\__/ /_| |_  /\__/ / || (_| | (__|   < 
\_| |_/\___|\__\__,_|_|   \__,_|___/ \_|  \__,_|_|_|       \___/\____/ \___/  \____/ \__\__,_|\___|_|\_\
                                                                                                        
                                                                                                        
______     _            _                             _   _      _                      _               
| ___ \   (_)          | |                           | \ | |    | |                    | |              
| |_/ / __ ___   ____ _| |_ ___ _ __   ___  ___ ___  |  \| | ___| |___      _____  _ __| | __           
|  __/ '__| \ \ / / _` | __/ _ \ '_ \ / _ \/ __/ __| | . ` |/ _ \ __\ \ /\ / / _ \| '__| |/ /           
| |  | |  | |\ V / (_| | ||  __/ | | |  __/\__ \__ \_| |\  |  __/ |_ \ V  V / (_) | |  |   <            
\_|  |_|  |_| \_/ \__,_|\__\___|_| |_|\___||___/___(_)_| \_/\___|\__| \_/\_/ \___/|_|  |_|\_\           
                                                                                                        
                                                                                                        
EOF
}

compose() {
  if command -v docker-compose >/dev/null 2>&1; then
    docker-compose -f "$COMPOSE_FILE" "$@"
  else
    docker compose -f "$COMPOSE_FILE" "$@"
  fi
}

require_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo -e "${red}Docker is not installed or not in PATH.${reset}"
    return 1
  fi
  if ! docker info >/dev/null 2>&1; then
    echo -e "${red}Docker daemon is not running.${reset}"
    return 1
  fi
}

wait_for_emercoin_core() {
  echo
  echo -e "${yellow}Waiting for emercoin-core healthcheck...${reset}"
  require_docker || return 1

  local attempts=12
  local i status
  for i in $(seq 1 "$attempts"); do
    status=$(docker inspect --format='{{.State.Health.Status}}' emercoin-core 2>/dev/null || echo "unknown")
    echo "  - attempt ${i}/${attempts}: emercoin-core health=${status}"
    if [ "$status" = "healthy" ]; then
      echo -e "${green}${check_ok_symbol}${reset} emercoin-core is healthy."
      return 0
    fi
    sleep 10
  done

  echo -e "${red}${check_fail_symbol}${reset} emercoin-core did not become healthy in time. Check 'docker logs emercoin-core'."
  return 1
}

ping_host() {
  local host="$1"
  # Try Linux-style ping first; if it fails, fall back to Windows syntax.
  if ping -c 1 127.0.0.1 >/dev/null 2>&1; then
    ping -c 2 "$host"
  else
    ping -n 2 "$host"
  fi
}

stack_status() {
  if [ ! -f "$COMPOSE_FILE" ]; then
    echo "compose file $COMPOSE_FILE not found"
    return 1
  fi
  if ! command -v docker >/dev/null 2>&1; then
    echo "docker not available"
    return 1
  fi

  local count
  count=$(compose ps 2>/dev/null | awk 'NR>2 && $1!="" {print $1}' | wc -l | tr -d ' ')
  if [ "$count" -eq 0 ] 2>/dev/null; then
    echo "stopped"
  else
    echo "$count service(s) listed"
  fi
}

print_info() {
  echo -e "${magenta}"
  logo
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
  disk=$(df -h / 2>/dev/null | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}' || echo "?")

  if command -v docker >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1; then
      docker_status="running"
    else
      docker_status="installed (daemon not running)"
    fi
  else
    docker_status="not installed"
  fi

  stack=$(stack_status 2>/dev/null || echo "unknown")

  echo -e "${cyan}Host${reset}:           $host"
  echo -e "${cyan}OS${reset}:             $os"
  echo -e "${cyan}Kernel${reset}:         $kernel"
  echo -e "${cyan}Uptime${reset}:         $uptime"
  echo -e "${cyan}CPU${reset}:            ${cpu:-"?"}"
  echo -e "${cyan}Memory${reset}:         $mem"
  echo -e "${cyan}Disk (/)${reset}:       $disk"
  echo -e "${cyan}Docker${reset}:         $docker_status"
  echo -e "${cyan}Ness stack${reset}:     $stack"
}

check_entropy() {
  if [ -r /proc/sys/kernel/random/entropy_avail ]; then
    local val
    val=$(cat /proc/sys/kernel/random/entropy_avail)
    echo "Entropy available: $val"
  else
    echo "Entropy info not available on this system."
  fi
}

start_single_service() {
  local svc="$1"
  local label="$2"

  echo
  echo -e "${yellow}Starting service: ${label}...${reset}"
  require_docker || return 1

  compose up -d "$svc"

  # If we just started emercoin-core, wait for its healthcheck
  if [ "$svc" = "emercoin-core" ]; then
    wait_for_emercoin_core || true
  fi
}

start_stack() {
  echo
  echo -e "${yellow}Starting Ness Essential stack...${reset}"
  if [ -x "./deploy-ness.sh" ]; then
    ./deploy-ness.sh
  else
    require_docker || return 1
    compose up -d
  fi

  # Enforce dependency order by waiting for Emercoin Core to report healthy
  wait_for_emercoin_core || true
}

start_services_menu() {
  while true; do
    echo
    echo -e "${green}Start services menu (Ness Essential stack):${reset}"
    echo "  1) Start EVERYTHING (full stack)"
    echo "  2) Start Emercoin Core only"
    echo "  3) Start pyuheprng-privatenesstools only"
    echo "  4) Start DNS reverse proxy only"
    echo "  5) Start Privateness only"
    echo "  6) Start IPFS only"
    echo "  0) Back"
    echo
    read -rp "Select an option: " choice
    case "$choice" in
      1) start_stack ;;
      2) start_single_service "emercoin-core" "Emercoin Core" ;;
      3) start_single_service "pyuheprng-privatenesstools" "pyuheprng-privatenesstools" ;;
      4) start_single_service "dns-reverse-proxy" "DNS reverse proxy" ;;
      5) start_single_service "privateness" "Privateness" ;;
      6) start_single_service "ipfs" "IPFS" ;;
      0) return 0 ;;
      *) echo "Invalid choice." ;;
    esac
  done
}

stop_stack() {
  echo
  echo -e "${yellow}Stopping Ness Essential stack...${reset}"
  require_docker || return 1
  compose down
}

status_stack() {
  echo
  echo -e "${yellow}Stack status:${reset}"
  require_docker || return 1
  compose ps
}

logs_stack() {
  echo
  echo -e "${yellow}Tailing stack logs (Ctrl+C to exit)...${reset}"
  require_docker || return 1
  compose logs -f
}

remove_everything_local() {
  echo
  echo -e "${red}WARNING: This will remove ALL local Docker containers, images, volumes, networks, and build cache on this host.${reset}"
  echo -e "${red}It does NOT touch any remote repositories (Docker Hub) or delete anything server-side.${reset}"
  echo
  read -rp "Type 'ness' to confirm full local Docker cleanup: " answer
  if [ "$answer" != "ness" ]; then
    echo "Aborted."
    return 1
  fi

  require_docker || return 1

  echo
  echo -e "${yellow}Stopping all running Docker containers...${reset}"
  docker ps -aq | xargs -r docker stop || true

  echo
  echo -e "${yellow}Removing all Docker containers...${reset}"
  docker ps -aq | xargs -r docker rm -f || true

  echo
  echo -e "${yellow}Removing all local Docker images (any namespace)...${reset}"
  docker images -aq | xargs -r docker rmi -f || true

  echo
  echo -e "${yellow}Pruning Docker build cache (all builders, local only)...${reset}"
  docker builder prune -af || true

  echo
  echo -e "${yellow}Pruning unused Docker data (dangling images, networks, etc.)...${reset}"
  docker system prune -af --volumes || true

  echo
  echo -e "${green}Local cleanup complete.${reset}"
}

build_all_images() {
  echo
  if [ -x "./build-all.sh" ]; then
    echo -e "${yellow}Running build-all.sh (build all images)...${reset}"
    ./build-all.sh
  else
    echo "build-all.sh not found or not executable."
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
    "privatenumer"
    "privatenesstools"
    "pyuheprng-privatenesstools"
    "ipfs"
    "i2p-yggdrasil"
    "amneziawg"
    "skywire-amneziawg"
    "amnezia-exit"
    "ness-unified"
  )

  echo -e "${yellow}Select image to build:${reset}"
  local idx=1
  for img in "${images[@]}"; do
    echo "  ${idx}) ${img}"
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
  while true; do
    echo
    echo -e "${green}Build images menu:${reset}"
    echo "  1) Build ALL images (build-all.sh)"
    echo "  2) Build ALL images (NO CACHE)"
    echo "  3) Build single image"
    echo "  0) Back"
    echo
    read -rp "Select an option: " choice
    case "$choice" in
      1) build_all_images ;;
      2) NO_CACHE=1 build-all.sh ;;
      3) build_single_image ;;
      0) return 0 ;;
      *) echo "Invalid choice." ;;
    esac
  done
}

test_everything() {
  echo
  echo -e "${yellow}Running full test suite (entropy + core node health)...${reset}"
  check_entropy
  health_check
}

test_individual_menu() {
  while true; do
    echo
    echo -e "${green}Test individual components:${reset}"
    echo "  1) Core node health check"
    echo "  2) Entropy check"
    echo "  0) Back"
    echo
    read -rp "Select an option: " choice
    case "$choice" in
      1) health_check ;;
      2) check_entropy ;;
      0) return 0 ;;
      *) echo "Invalid choice." ;;
    esac
  done
}

live_status_widget() {
  require_docker || return 1

  while true; do
    clear
    echo -e "${green}Ness Live Status (updates every 10 seconds, Ctrl+C to exit)...${reset}"
    echo

    local stack
    stack=$(stack_status 2>/dev/null || echo "unknown")
    echo "Stack: $stack"
    echo

    local emc_status
    emc_status=$(docker inspect --format='{{.State.Health.Status}}' emercoin-core 2>/dev/null || echo "unknown")
    if [ "$emc_status" = "healthy" ]; then
      echo -e "emercoin-core:   ${green}HEALTHY${reset}"
    else
      echo -e "emercoin-core:   ${red}${emc_status}${reset}"
    fi

    if docker ps --format '{{.Names}}' | grep -q '^privateness$'; then
      echo -e "privateness:     ${green}RUNNING${reset}"
    else
      echo -e "privateness:     ${red}STOPPED${reset}"
    fi

    echo
    echo "Next refresh in 10 seconds..."
    sleep 10
  done
}

test_menu() {
  while true; do
    echo
    echo -e "${green}Test / Status menu:${reset}"
    echo "  1) Test EVERYTHING"
    echo "  2) Test individual component"
    echo "  3) Live status widget (refresh every 10s)"
    echo "  0) Back"
    echo
    read -rp "Select an option: " choice
    case "$choice" in
      1) test_everything ;;
      2) test_individual_menu ;;
      3) live_status_widget ;;
      0) return 0 ;;
      *) echo "Invalid choice." ;;
    esac
  done
}

examples_nvs_dns() {
  echo
  echo -e "${green}Emercoin NVS / DNS examples:${reset}"
  cat <<'EOF'
# Show canonical NVS entry (replace "emercoin-cli" with "emc" if needed)
emercoin-cli name_show ness:therulesoftheinternet | python ./emercoin-value.py

# Show wallet NVS entry
emercoin-cli name_show ness:wallet | python ./emercoin-value.py

# Show DNS NVS entry used by Ness
emercoin-cli name_show dns:private.ness | python ./emercoin-value.py

# Resolve DNS via local dns-reverse-proxy
dig @127.0.0.1 private.ness
ping private.ness
EOF
}

examples_health() {
  echo
  echo -e "${green}Health / monitoring examples:${reset}"
  cat <<'EOF'
# Show Ness Essential stack services
docker-compose -f docker-compose.ness.yml ps

# Tail logs for a single service
docker logs -f emercoin-core

# Check pyuheprng health
curl -s http://localhost:5000/health

# Check privatenesstools health
curl -s http://localhost:8888/health
EOF
}

examples_attacks() {
  echo
  echo -e "${green}Attack scenarios (from INCENTIVE-SECURITY.md):${reset}"
  cat <<'EOF'
Attack: Run modified binary
  - Attacker modifies node binary to steal data.
  - Binary hash doesn't match manifest.
  - Result: node rejected, no payment.

Attack: Fake binary hash
  - Attacker reports a fake hash to match expected.
  - Network sends challenge-response test.
  - Result: challenge fails, no payment.

Attack: Run legitimate binary + separate attack tool
  - Attacker runs legitimate binary to get paid.
  - Also runs separate tool to attack the network.
  - Again challenge response test will detect such attempts.
  - Result: node banned, payments stopped.

Attack: Replay challenge responses
  - Attacker records legitimate responses and replays them.
  - Network uses fresh random challenges every time with nonce and salt
  - Result: replay fails, verification fails, no payment.
EOF
}

examples_menu() {
  while true; do
    echo
    echo -e "${green}Examples menu:${reset}"
    echo "  1) Emercoin NVS / DNS examples"
    echo "  2) Health / monitoring examples"
    echo "  3) Attack scenarios (summary)"
    echo "  0) Back"
    echo
    read -rp "Select an option: " choice
    case "$choice" in
      1) examples_nvs_dns ;;
      2) examples_health ;;
      3) examples_attacks ;;
      0) return 0 ;;
      *) echo "Invalid choice." ;;
    esac
  done
}

health_check() {
  echo
  echo -e "${yellow}Core node health check...${reset}"
  require_docker || return 1

  local overall_rc=0
  local warning_rc=0

  echo
  echo "== Docker services (Ness Essential stack) =="
  compose ps
  local rc_ps=$?
  if [ "$rc_ps" -eq 0 ]; then
    echo -e " ${green}${check_ok_symbol}${reset} Docker stack reachable"
  else
    echo -e " ${red}${check_fail_symbol}${reset} Docker stack reachable"
    overall_rc=1
  fi

  echo
  echo "== Privateness vs explorer (seq/block_hash) =="
  if docker ps --format '{{.Names}}' | grep -q '^privateness$'; then
    echo "-- Explorer:"
    local explorer_health
    explorer_health=$(curl -s https://ness-explorer.magnetosphere.net/api/health)
    local rc_explorer=$?
    echo "$explorer_health" | grep -E 'seq|block_hash' || true

    echo
    echo "-- Local node (privateness-cli status):"
    local local_status
    local_status=$(docker exec privateness privateness-cli status 2>/dev/null)
    local rc_local=$?
    echo "$local_status" | grep -E 'seq|block_hash' || true

    if [ "$rc_explorer" -eq 0 ] && echo "$explorer_health" | grep -q 'seq' \
       && [ "$rc_local" -eq 0 ] && echo "$local_status" | grep -q 'seq'; then
      echo -e " ${green}${check_ok_symbol}${reset} Privateness height/hash match explorer (seq/block_hash)"
    else
      echo -e " ${red}${check_fail_symbol}${reset} Privateness height/hash match explorer (seq/block_hash)"
      overall_rc=1
    fi
  else
    echo "privateness container is not running."
    echo -e " ${red}${check_fail_symbol}${reset} Privateness container running"
    overall_rc=1
  fi

  echo
  echo "== Emercoin vs explorer =="
  local EMERCOIN_CLI=""
  if command -v emercoin-cli >/dev/null 2>&1; then
    EMERCOIN_CLI="emercoin-cli"
  elif command -v emc >/dev/null 2>&1; then
    EMERCOIN_CLI="emc"
  fi

  if [ -n "$EMERCOIN_CLI" ]; then
    echo "-- Explorer block height:"
    local emc_height
    emc_height=$(curl -s https://explorer.emercoin.com/api/stats/block_height)
    local rc_emc_height=$?
    echo "$emc_height" || true

    echo
    echo "-- Local $EMERCOIN_CLI blocks:"
    local emc_local_info
    emc_local_info=$("$EMERCOIN_CLI" getblockchaininfo 2>/dev/null)
    local rc_emc_local=$?
    echo "$emc_local_info" | grep blocks || true

    echo
    echo "-- Explorer latest block hash:"
    local emc_explorer_hash
    emc_explorer_hash=$(curl -s https://explorer.emercoin.com/api/block/latest | grep blockhash)
    local rc_emc_explorer_hash=$?
    echo "$emc_explorer_hash" || true

    echo
    echo "-- Local $EMERCOIN_CLI best block hash:"
    local emc_local_hash
    emc_local_hash=$("$EMERCOIN_CLI" getbestblockhash 2>/dev/null)
    local rc_emc_local_hash=$?
    echo "$emc_local_hash" || true

    if [ "$rc_emc_height" -eq 0 ] && [ "$rc_emc_local" -eq 0 ] \
       && [ "$rc_emc_explorer_hash" -eq 0 ] && [ "$rc_emc_local_hash" -eq 0 ]; then
      echo -e " ${green}${check_ok_symbol}${reset} Emercoin height/hash match explorer (manual comparison)"
    else
      echo -e " ${red}${check_fail_symbol}${reset} Emercoin height/hash match explorer (manual comparison)"
      overall_rc=1
    fi
  else
    echo "emercoin-cli/emc not found on host; skipping Emercoin checks."
    echo -e " ${yellow}${check_fail_symbol}${reset} Emercoin CLI available on host (warning only)"
    warning_rc=1
  fi

  echo
  echo "== EmerNVS & DNS resolution (host) =="
  if [ -n "$EMERCOIN_CLI" ]; then
    echo "-- NVS dns:private.ness:"
    if "$EMERCOIN_CLI" name_show dns:private.ness 2>/dev/null | python "$SCRIPT_DIR/emercoin-value.py"; then
      echo -e " ${green}${check_ok_symbol}${reset} NVS dns:private.ness reachable"
    else
      echo -e " ${red}${check_fail_symbol}${reset} NVS dns:private.ness reachable"
      overall_rc=1
    fi

    echo
    echo "-- Ping private.ness:"
    if ping_host private.ness; then
      echo -e " ${green}${check_ok_symbol}${reset} DNS resolution for private.ness"
    else
      echo -e " ${red}${check_fail_symbol}${reset} DNS resolution for private.ness"
      overall_rc=1
    fi

    echo
    echo "-- NVS dns:vpn.sky:"
    if "$EMERCOIN_CLI" name_show dns:vpn.sky 2>/dev/null | python "$SCRIPT_DIR/emercoin-value.py"; then
      echo -e " ${green}${check_ok_symbol}${reset} NVS dns:vpn.sky reachable"
    else
      echo -e " ${red}${check_fail_symbol}${reset} NVS dns:vpn.sky reachable"
      overall_rc=1
    fi

    echo
    echo "-- Ping vpn.sky:"
    if ping_host vpn.sky; then
      echo -e " ${green}${check_ok_symbol}${reset} DNS resolution for vpn.sky"
    else
      echo -e " ${red}${check_fail_symbol}${reset} DNS resolution for vpn.sky"
      overall_rc=1
    fi
  else
    echo "Emercoin CLI not found; skipping NVS checks."
    warning_rc=1
  fi

  echo
  echo "-- Ping emercoin.com:"
  if ping_host emercoin.com; then
    echo -e " ${green}${check_ok_symbol}${reset} Internet connectivity to emercoin.com"
  else
    echo -e " ${red}${check_fail_symbol}${reset} Internet connectivity to emercoin.com"
    overall_rc=1
  fi

  echo
  if [ "$overall_rc" -eq 0 ] && [ "${warning_rc:-0}" -eq 0 ]; then
    echo -e "${green}===== GLOBAL STATUS: SUCCESS =====${reset}"
  elif [ "$overall_rc" -eq 0 ] && [ "${warning_rc:-0}" -ne 0 ]; then
    echo -e "${yellow}===== GLOBAL STATUS: WARNING =====${reset}"
  else
    echo -e "${red}===== GLOBAL STATUS: FAILED =====${reset}"
  fi
}

play_menu_cast() {
  if ! command -v asciinema >/dev/null 2>&1; then
    echo "asciinema is not installed or not in PATH."
    echo "See README.md for installation instructions."
    return 1
  fi

  if [ ! -f "$SCRIPT_DIR/1ness-menu.cast" ]; then
    echo "Cast file not found: $SCRIPT_DIR/1ness-menu.cast"
    return 1
  fi

  asciinema play "$SCRIPT_DIR/1ness-menu.cast"
}

menu() {
  while true; do
    clear
    print_info
    echo
    echo -e "${green}Menu:${reset}"
    echo "  00) Play menu demo (asciinema)"
    echo "  1) Build images (all / individual)"
    echo "  2) Start Ness Essential stack"
    echo "  3) Test / Status menu"
    echo "  4) Show stack status"
    echo "  5) Tail stack logs"
    echo "  6) Check entropy"
    echo "  7) Core node health check"
    echo "  8) Remove everything local (containers/images/volumes)"
    echo "  9) Examples (NVS/DNS/health/attacks)"
    echo "  0) Exit"
    echo
    read -rp "Select an option: " choice
    case "$choice" in
      00) play_menu_cast ;;
      1) build_images_menu ;;
      2) start_services_menu ;;
      3) test_menu ;;
      4) status_stack ;;
      5) logs_stack ;;
      6) check_entropy ;;
      7) health_check ;;
      8) remove_everything_local ;;
      9) examples_menu ;;
      0) exit 0 ;;
      *) echo "Invalid choice." ;;
    esac
    echo
    read -rp "Press Enter to continue..." _pause
  done
}

menu
