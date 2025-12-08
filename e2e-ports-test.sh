#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_USER="${DOCKER_USER:-nessnetwork}"

# Local copy of tier image sets (keep in sync with build-multiarch.sh)
TIER1_IMAGES=(
  "emercoin-core"
  "skywire"
  "dns-reverse-proxy"
  "privateness"
  "pyuheprng"
  "privatenesstools"
)

TIER2_IMAGES=(
  "amneziawg"
  "skywire-amneziawg"
  "amnezia-exit"
  "yggdrasil"
  "i2p-yggdrasil"
  "ness-unified"
)

# By default we test Tier 1 images only (Tier 2 relies on full-stack logs)
SELECTED_IMAGES=("${TIER1_IMAGES[@]}")

# Simple ANSI colors
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
reset='\033[0m'

info()  { echo -e "${yellow}[INFO]${reset} $*"; }
pass()  { echo -e "${green}[PASS]${reset} $*"; }
fail()  { echo -e "${red}[FAIL]${reset} $*"; }
skip()  { echo -e "${yellow}[SKIP]${reset} $*"; }

check_endpoint() {
  local image="$1"
  local port="$2"

  case "${image}:${port}" in
    "emercoin-core:6662")
      # Emercoin JSON-RPC getblockchaininfo
      local payload='{"jsonrpc":"1.0","id":"e2e","method":"getblockchaininfo","params":[]}'
      if curl -s --max-time 8 \
           -H 'content-type:text/plain;' \
           --data-binary "$payload" \
           http://127.0.0.1:6662/ | grep -q '"result"'; then
        return 0
      else
        return 1
      fi
      ;;

    "dns-reverse-proxy:8053")
      # DNS reverse proxy HTTP health endpoint
      if curl -s --max-time 8 http://127.0.0.1:8053/health >/dev/null 2>&1; then
        return 0
      else
        return 1
      fi
      ;;

    "skywire:8000")
      # Skywire visor HTTP UI
      if curl -s --max-time 8 http://127.0.0.1:8000/ | grep -qi "skywire"; then
        return 0
      else
        return 1
      fi
      ;;

    "privateness:6660")
      # Privateness JSON-RPC status
      local p='{"jsonrpc":"2.0","id":"e2e","method":"status","params":[]}'
      if curl -s --max-time 8 \
           -H 'content-type: application/json' \
           -d "$p" \
           http://127.0.0.1:6660/ | grep -qi '"status"'; then
        return 0
      else
        return 1
      fi
      ;;

    *)
      # No special check; caller should treat as generic TCP-only and
      # typically SKIP so the operator can inspect full stack logs instead.
      return 2
      ;;
  esac
}

require_cmd() {
  for c in "$@"; do
    if ! command -v "$c" >/dev/null 2>&1; then
      echo "Missing required command: $c" >&2
      exit 1
    fi
  done
}

require_cmd docker awk grep sed curl

# Scan top-level image directories for Dockerfiles
mapfile -t DOCKERFILES < <(find "$SCRIPT_DIR" -maxdepth 2 -type f -name 'Dockerfile' | sort)

if [[ ${#DOCKERFILES[@]} -eq 0 ]]; then
  fail "No Dockerfiles found under $SCRIPT_DIR"
  exit 1
fi

TOTAL_EXPOSED=0
TEST_PASSED=0
TEST_FAILED=0
TEST_SKIPPED=0
IMAGE_MISSING=0

image_in_selected_tiers() {
  local name="$1"
  local img
  for img in "${SELECTED_IMAGES[@]}"; do
    if [[ "$img" == "$name" ]]; then
      return 0
    fi
  done
  return 1
}

is_port_free() {
  local port="$1"

  # Prefer ss if available
  if command -v ss >/dev/null 2>&1; then
    if ss -tuln 2>/dev/null | awk '{print $5}' | grep -q ":${port}$"; then
      return 1
    fi
    return 0
  fi

  # Fallback to netstat (Windows / legacy envs)
  if command -v netstat >/dev/null 2>&1; then
    if netstat -an 2>/dev/null | awk '{print $4}' | grep -q ":${port}$"; then
      return 1
    fi
    return 0
  fi

  # If we cannot inspect, assume free and let docker run decide
  return 0
}

wait_tcp_open() {
  local port="$1"; shift
  local timeout="${1:-15}"
  local start ts
  start=$(date +%s)
  while true; do
    # Prefer nc if available
    if command -v nc >/dev/null 2>&1; then
      if nc -z 127.0.0.1 "$port" >/dev/null 2>&1; then
        return 0
      fi
    else
      # Fallback: bash /dev/tcp if supported
      if ( : < /dev/tcp/127.0.0.1/"$port" ) >/dev/null 2>&1; then
        return 0
      fi
    fi

    ts=$(date +%s)
    if (( ts - start >= timeout )); then
      return 1
    fi
    sleep 0.5
  done
}

for dockerfile in "${DOCKERFILES[@]}"; do
  image_dir="$(cd "$(dirname "$dockerfile")" && pwd)"
  image_name="$(basename "$image_dir")"
  image_ref="${DOCKER_USER}/${image_name}:latest"

  # Only test Tier 1 + Tier 2 images
  if ! image_in_selected_tiers "$image_name"; then
    continue
  fi

  info "--- Image: ${image_ref} (Dockerfile: ${dockerfile}) ---"

  if ! docker image inspect "$image_ref" >/dev/null 2>&1; then
    skip "Image not present locally, skipping tests for $image_ref"
    ((IMAGE_MISSING++))
    continue
  fi

  # Collect exposed ports from Dockerfile
  mapfile -t EXPOSE_LINES < <(grep -E '^EXPOSE ' "$dockerfile" || true)
  if [[ ${#EXPOSE_LINES[@]} -eq 0 ]]; then
    skip "No EXPOSE directives in $dockerfile"
    continue
  fi

  for line in "${EXPOSE_LINES[@]}"; do
    # Strip leading EXPOSE and normalize whitespace
    ports_part="$(echo "$line" | sed -E 's/^EXPOSE[[:space:]]+//')"
    for token in $ports_part; do
      # token may be like 53/tcp, 53/udp or just 53
      port="${token%%/*}"
      proto="${token##*/}"
      if [[ "$proto" == "$port" ]]; then
        proto="tcp"  # default
      fi

      ((TOTAL_EXPOSED++))
      test_id="${image_name}_${port}_${proto}"

      if [[ "$proto" != "tcp" ]]; then
        skip "$test_id: non-tcp EXPOSE ($proto) - not actively probed yet"
        ((TEST_SKIPPED++))
        continue
      fi

      if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        skip "$test_id: unable to parse port token '$token'"
        ((TEST_SKIPPED++))
        continue
      fi

      if ! is_port_free "$port"; then
        skip "$test_id: host port $port already in use (respecting existing listener)"
        ((TEST_SKIPPED++))
        continue
      fi

      container_name="e2e-${image_name}-${port}-$$"
      info "$test_id: starting temporary container $container_name"
      if ! docker run -d --rm --name "$container_name" -p "${port}:${port}" "$image_ref" >/dev/null 2>&1; then
        fail "$test_id: failed to start container"
        ((TEST_FAILED++))
        continue
      fi

      if wait_tcp_open "$port" 20; then
        # If we have a service-specific endpoint check, run it
        ep_rc=0
        if check_endpoint "$image_name" "$port"; then
          pass "$test_id: endpoint OK (service-specific check)"
          ((TEST_PASSED++))
        else
          ep_rc=$?
        fi

        if [[ $ep_rc -eq 2 ]]; then
          # No endpoint defined for this image/port; rely on stack logs
          skip "$test_id: TCP ${port} reachable, no endpoint-level check (inspect stack logs)"
          ((TEST_SKIPPED++))
        elif [[ $ep_rc -ne 0 ]]; then
          fail "$test_id: TCP port ${port} open but endpoint check failed"
          ((TEST_FAILED++))
        fi
      else
        fail "$test_id: TCP port ${port} did not open within timeout"
        ((TEST_FAILED++))
      fi

      docker stop "$container_name" >/dev/null 2>&1 || true
    done
  done

  echo
done

echo "Summary:"
echo "  Total EXPOSEd endpoints: $TOTAL_EXPOSED"
echo "  Passed:                  $TEST_PASSED"
echo "  Failed:                  $TEST_FAILED"
echo "  Skipped:                 $TEST_SKIPPED"
echo "  Images missing locally:  $IMAGE_MISSING"

if (( TEST_FAILED > 0 )); then
  exit 1
fi

exit 0
