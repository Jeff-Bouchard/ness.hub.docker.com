#!/usr/bin/env bash
#
# ness-portainer.sh - Launch Portainer + NESS Stack
#

set -euo pipefail

R=$'\033[0m'
G=$'\033[32m'
Y=$'\033[33m'
C=$'\033[36m'
B=$'\033[1m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

check_docker() {
    if ! command -v docker &>/dev/null; then
        echo "Error: Docker not found"
        exit 1
    fi
    if ! docker info &>/dev/null; then
        echo "Error: Docker daemon not running"
        exit 1
    fi
}

start_portainer() {
    echo "Starting Portainer..."
    docker compose -f portainer-compose.yaml up -d 2>/dev/null || \
        docker run -d -p 55443:9443 --name portainer --restart always \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v portainer_data:/data portainer/portainer-ce:lts
}

start_ness() {
    echo "Starting NESS stack ($1)..."
    case "$1" in
        pi3)
            docker compose up -d emercoin-core
            sleep 3
            docker compose up -d privateness skywire dns-reverse-proxy pyuheprng-tools
            ;;
        skyminer)
            docker compose up -d emercoin-core privateness dns-reverse-proxy pyuheprng-tools
            ;;
        *) docker compose up -d ;;
    esac
}

echo "NESS + Portainer Launcher"
echo "========================"
echo
check_docker

if [[ "${1:-}" == "stop" ]]; then
    docker compose down
    docker compose -f portainer-compose.yaml down 2>/dev/null || docker stop portainer
    echo "Stopped"
    exit 0
fi

start_portainer
start_ness "${1:-pi3}"

ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
echo
echo "✓ Done! Access Portainer at: https://$ip:55443"
echo "  (Login and select 'Local' to manage containers)"
