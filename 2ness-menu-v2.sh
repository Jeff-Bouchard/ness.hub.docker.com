#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

COMPOSE_FILE="docker-compose.yml"
DOCKER_USER="nessnetwork"
PROFILE="full" # Default to full, user can change
DNS_MODE="hybrid" # icann|hybrid|emerdns

DNS_LABEL_FILE="$SCRIPT_DIR/.dns_mode_labels"
DNS_LABEL_ICANN="ICANN-only (deny EmerDNS)"
DNS_LABEL_HYBRID="Hybrid (EmerDNS first, ICANN fallback)"
DNS_LABEL_EMERDNS="EmerDNS-only (deny ICANN)"

cyan="\033[1;36m"
magenta="\033[1;35m"
yellow="\033[1;33m"
green="\033[1;32m"
red="\033[1;31m"
reset="\033[0m"

check_ok_symbol="✔"
check_fail_symbol="✘"

# ... logo ...

select_profile() {
  echo
  echo -e "${green}Select Hardware Profile:${reset}"
  echo "  1) Raspberry Pi 3 / Low Spec (Essentials Only)"
  echo "     -> Runs: Emercoin, Privateness, Skywire, DNS, IPFS, Tools"
  echo "     -> Skips: Amnezia, Yggdrasil, I2P, Unified (Heavy/Unstable on Pi3)"
  echo
  echo "  2) Raspberry Pi 4 / PC (Full Node)"
  echo "     -> Runs: EVERYTHING"
  echo
  read -rp "Select profile [1-2]: " p_choice
  case "$p_choice" in
    1)
      PROFILE="pi3"
      echo -e "${yellow}Profile set to: Pi 3 (Essentials)${reset}"
      ;;
    2)
      PROFILE="full"
      echo -e "${yellow}Profile set to: Full Node${reset}"
      ;;
    *)
      echo "Invalid choice, keeping current: $PROFILE"
      ;;
  esac
}

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
    0)
      DNS_MODE="icann"
      ;;
    1)
      DNS_MODE="hybrid"
      ;;
    2)
      DNS_MODE="emerdns"
      ;;
    *)
      echo "Invalid choice, keeping current: $DNS_MODE"
      ;;
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

start_stack() {
  echo
  echo -e "${yellow}Starting Ness stack (Profile: $PROFILE)...${reset}"
  
  require_docker || return 1

  if [ "$PROFILE" = "pi3" ]; then
    # Explicitly start ONLY the Pi 3 safe revenue stack
    compose up -d \
      emercoin-core \
      privateness \
      skywire \
      dns-reverse-proxy \
      pyuheprng \
      privatenesstools \
      ipfs
      # Note: Yggdrasil, I2P, Amnezia, Privatenumer are excluded
  else
    # Start everything
    compose up -d
  fi

  wait_for_emercoin_core || true
}

print_info() {
  echo -e "${magenta}"
  logo
  echo -e "${reset}"

  # ... existing host checks ...
  local host os kernel uptime cpu mem disk docker_status stack
  host=$(hostname 2>/dev/null || echo "?")
  if [ -r /etc/os-release ]; then
    os=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2- | tr -d '"')
  else
    os=$(uname -s 2>/dev/null || echo "?")
  fi
  # ... keep existing logic ...
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
  echo -e "${cyan}Reality${reset}:        ${yellow}$DNS_MODE${reset} (${DNS_DESC})"
  echo -e "${cyan}Active Profile${reset}: ${yellow}$PROFILE${reset}"
  echo -e "${cyan}Docker User${reset}:    $DOCKER_USER"
}

# ... existing functions ...

menu() {
  while true; do
    clear
    print_info
    echo
    echo -e "${green}Menu V2 (Release Mode):${reset}"
    echo "  0) Reality / DNS Mode (Current: $DNS_MODE -> $DNS_DESC)"
    echo "  1) Select Hardware/Profile (Current: $PROFILE)"
    echo "  2) Build images (Multi-Arch Release)"
    echo "  3) Start Ness Stack (Respects Profile)"
    echo "  4) Show stack status"
    echo "  5) Tail stack logs"
    echo "  6) Check entropy"
    echo "  7) Remove everything local"
    echo "  8) Rename Reality Modes"
    echo "  9) Exit"
    echo
    read -rp "Select an option: " choice
    case "$choice" in
      0) select_dns_mode ;;
      1) select_profile ;;
      2) build_images_menu ;;
      3) start_services_menu ;;
      4) status_stack ;;
      5) logs_stack ;;
      6) check_entropy ;;
      7) remove_everything_local ;;
      8) edit_dns_mode_labels ;;
      9) exit 0 ;;
      *) echo "Invalid choice." ;;
    esac
    echo
    read -rp "Press Enter to continue..." _pause
  done
}
