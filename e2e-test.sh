#!/usr/bin/env bash
# NESS Stack E2E Test - v2.1
# Tests each component and shows actual errors

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo ".")"
cd "$SCRIPT_DIR"

# Detect engine
if command -v podman-compose &>/dev/null && podman info &>/dev/null 2>&1; then
    ENGINE="podman-compose"
    RUNTIME="podman"
    COMPOSE_CMD="podman-compose"
elif command -v docker-compose &>/dev/null; then
    ENGINE="docker-compose"
    RUNTIME="docker"
    COMPOSE_CMD="docker-compose"
else
    echo "[ERROR] No container engine found (podman-compose or docker-compose)"
    exit 1
fi

TEST_LOG="$SCRIPT_DIR/test-results.log"
echo "=== NESS E2E Test $(date) ===" > "$TEST_LOG"

cyan="\033[1;36m"
green="\033[1;32m"
red="\033[1;31m"
yellow="\033[1;33m"
reset="\033[0m"

log() {
    echo -e "${cyan}[$(date '+%H:%M:%S')]${reset} $1" | tee -a "$TEST_LOG"
}

fail() {
    echo -e "${red}[FAIL]${reset} $1" | tee -a "$TEST_LOG"
    ((FAIL_COUNT++)) || true
}

pass() {
    echo -e "${green}[PASS]${reset} $1" | tee -a "$TEST_LOG"
    ((PASS_COUNT++)) || true
}

warn() {
    echo -e "${yellow}[WARN]${reset} $1" | tee -a "$TEST_LOG"
}

PASS_COUNT=0
FAIL_COUNT=0

log "=== NESS Stack E2E Test ==="
log "Engine: $ENGINE / $RUNTIME"
log "Working directory: $(pwd)"

# Test 2: Compose File Valid
log "Test 2: Checking docker-compose.yml..."
if $COMPOSE_CMD config > /dev/null 2>&1; then
    pass "docker-compose.yml syntax valid"
else
    fail "docker-compose.yml has errors"
    $COMPOSE_CMD config 2>&1 | head -20
fi

# Test 3: Volume Creation
log "Test 3: Checking volumes..."
for vol in emercoin-data skywire-data; do
    if $RUNTIME volume ls 2>/dev/null | grep -q "$vol"; then
        pass "Volume $vol exists"
    else
        log "  Creating $vol..."
        if $RUNTIME volume create "$vol" 2>/dev/null; then
            pass "Volume $vol created"
        else
            fail "Volume $vol creation failed"
        fi
    fi
done

services=(
    "emercoin-core:6661:tcp:Emercoin RPC"
    "privateness:6660:tcp:Privateness RPC"
    "dns-reverse-proxy:1053:tcp:DNS Proxy"
    "pyuheprng-privatenesstools:5000:tcp:pyuheprng"
    "softether-vpn:5555:tcp:SoftEther Management"
)

for service in "${services[@]}"; do
    IFS=':' read -r container port protocol label <<< "$service"
    
    # Container running check
    if ! $RUNTIME ps --format '{{.Names}}' | grep -q "^${container}$"; then
        fail "Container ${container} not running"
    fi
    
    # Port connectivity check
    if command -v nc >/dev/null 2>&1; then
        if nc -z localhost "$port" >/dev/null 2>&1; then
            pass "${label} port ${port} accessible"
        else
            fail "${label} port ${port} unreachable"
        fi
    else
        warn "nc not available - skipping port ${port} check"
    fi
done

# Test 4: Emercoin RPC test
log "Testing Emercoin RPC connectivity..."
if $RUNTIME exec emercoin-core emercoin-cli -datadir=/data getblockchaininfo >/dev/null 2>&1; then
    pass "Emercoin RPC responding"
else
    warn "Emercoin RPC not responding (may be syncing)"
fi

# Test 5: DNS resolution test
log "Testing DNS resolution..."
if command -v dig >/dev/null 2>&1; then
    if dig @127.0.0.1 -p 1053 +short example.com >/dev/null 2>&1; then
        pass "DNS reverse proxy resolving queries"
    else
        warn "DNS proxy not resolving queries"
    fi
else
    warn "dig not available - skipping DNS test"
fi

# Test 6: SoftEther management console
log "Testing SoftEther management..."
if $RUNTIME exec softether-vpn /usr/local/vpnserver/vpncmd localhost:5555 /SERVER /CMD ServerStatusGet >/dev/null 2>&1; then
    pass "SoftEther VPN management console accessible"
else
    warn "SoftEther VPN management console not responding"
fi

# Test 7: Service interdependencies
log "Testing service interdependencies..."
dependencies=(
    "privateness:emercoin-core"
    "dns-reverse-proxy:emercoin-core"
    "pyuheprng-privatenesstools:emercoin-core"
)

for dep in "${dependencies[@]}"; do
    IFS=':' read -r service dependency <<< "$dep"
    if $RUNTIME inspect "$service" | grep -q "$dependency"; then
        pass "${service} depends on ${dependency}"
    else
        warn "${service} dependency check failed"
    fi
done

# Test 8: Resource usage
log "Checking resource usage..."
$RUNTIME stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | tee -a "$TEST_LOG"

# Test 9: Volume integrity
log "Verifying volume mounts..."
volumes=("emercoin-data" "yggdrasil-data" "i2p-data" "skywire-data" "softether-data")
for vol in "${volumes[@]}"; do
    if $RUNTIME volume inspect "$vol" >/dev/null 2>&1; then
        pass "Volume ${vol} exists"
    else
        fail "Volume ${vol} missing"
    fi
done

# Test 10: Network connectivity
log "Testing network connectivity..."
if $RUNTIME network inspect ness-network >/dev/null 2>&1; then
    pass "Ness network bridge created"
else
    fail "Ness network bridge missing"
fi

log "E2E test suite completed!"
echo -e "\n${green}Test Summary:${reset}"
echo "Passed: $PASS_COUNT | Failed: $FAIL_COUNT"
echo "Logs: $TEST_LOG"
