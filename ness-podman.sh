#!/usr/bin/env bash
#
# ness-podman.sh - Simple podman menu for NESS Stack
#

set -euo pipefail

R=$'\033[0m'
G=$'\033[32m'
Y=$'\033[33m'
C=$'\033[36m'
B=$'\033[1m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ENGINE="${CONTAINER_ENGINE:-podman}"
PROFILE="${PROFILE:-pi3}"

clear_screen() {
    printf '\033[2J\033[H' 2>/dev/null || clear
}

show_menu() {
    clear_screen
    echo
    echo -e "${B}${C}=== NESS Podman Menu ===${R}"
    echo
    echo "  ${B}[1]${R} Start NESS Stack (profile: $PROFILE)"
    echo "  ${B}[2]${R} Stop NESS Stack"
    echo "  ${B}[3]${R} View Status"
    echo "  ${B}[4]${R} View Logs"
    echo "  ${B}[5]${R} Change Profile"
    echo
    echo "  ${B}[0]${R} Exit"
    echo
}

check_engine() {
    if ! command -v "$ENGINE" &>/dev/null; then
        echo "Error: $ENGINE not found"
        return 1
    fi
    if ! $ENGINE info &>/dev/null; then
        echo "Error: $ENGINE not running"
        return 1
    fi
    return 0
}

do_start() {
    if ! check_engine; then
        read -rp "Press Enter..."
        return
    fi
    
    echo -e "${C}Starting NESS with profile: $PROFILE${R}"
    
    # Stop existing
    $ENGINE compose down 2>/dev/null || true
    
    case "$PROFILE" in
        pi3)
            $ENGINE compose up -d emercoin-core
            sleep 3
            $ENGINE compose up -d privateness skywire dns-reverse-proxy pyuheprng-privatenesstools
            ;;
        skyminer)
            $ENGINE compose up -d emercoin-core
            sleep 3
            $ENGINE compose up -d privateness dns-reverse-proxy pyuheprng-privatenesstools
            ;;
        *)
            $ENGINE compose up -d
            ;;
    esac
    
    echo -e "${G}Started!${R}"
    read -rp "Press Enter..."
}

do_stop() {
    if ! check_engine; then
        read -rp "Press Enter..."
        return
    fi
    
    echo -e "${C}Stopping...${R}"
    $ENGINE compose down 2>/dev/null || true
    echo -e "${G}Stopped${R}"
    read -rp "Press Enter..."
}

do_status() {
    if ! check_engine; then
        read -rp "Press Enter..."
        return
    fi
    
    echo -e "${C}Container Status:${R}"
    $ENGINE compose ps 2>/dev/null || echo "No containers"
    echo
    $ENGINE ps --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || true
    read -rp "Press Enter..."
}

do_logs() {
    if ! check_engine; then
        read -rp "Press Enter..."
        return
    fi
    
    echo -e "${C}Logs (Ctrl+C to exit):${R}"
    $ENGINE compose logs -f --tail=50 2>/dev/null || $ENGINE logs -f --tail=50
}

do_profile() {
    echo
    echo "  1) pi3"
    echo "  2) skyminer"  
    echo "  3) full"
    echo
    read -rp "Select [1-3]: " p
    case "$p" in
        1) PROFILE="pi3" ;;
        2) PROFILE="skyminer" ;;
        3) PROFILE="full" ;;
        *) echo "Invalid"; sleep 1; return ;;
    esac
    echo "Profile: $PROFILE"
    read -rp "Press Enter..."
}

# Main
trap 'echo; echo "Exit"; exit 0' INT

while true; do
    show_menu
    read -rp "Select: " choice
    
    case "$choice" in
        1) do_start ;;
        2) do_stop ;;
        3) do_status ;;
        4) do_logs ;;
        5) do_profile ;;
        0|q) echo "Goodbye!"; exit 0 ;;
        *) echo "Invalid"; sleep 1 ;;
    esac
done
