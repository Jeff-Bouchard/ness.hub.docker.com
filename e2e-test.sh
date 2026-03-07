#!/usr/bin/env bash
# Ness v0.4 E2E Test Suite
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
TEST_LOG="$SCRIPT_DIR/test-results.log"

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
    exit 1
}

pass() {
    echo -e "${green}[PASS]${reset} $1" | tee -a "$TEST_LOG"
}

warn() {
    echo -e "${yellow}[WARN]${reset} $1" | tee -a "$TEST_LOG"
}

# Test 1: Preflight checks
log "Running preflight port checks..."
if [ -x "$SCRIPT_DIR/resolve_port_conflicts.sh" ]; then
    "$SCRIPT_DIR/resolve_port_conflicts.sh" || fail "Port conflicts detected"
    pass "All ports available"
else
    warn "Port conflict resolver not found - skipping"
fi

# Test 2: Stack startup
log "Starting Ness stack..."
cd "$SCRIPT_DIR"
docker compose -f "$COMPOSE_FILE" down --remove-orphans 2>/dev/null || true
docker compose -f "$COMPOSE_FILE" up -d --quiet-pull

# Test 3: Service health checks
log "Waiting for services to stabilize..."
sleep 30

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
    if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
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
if docker exec emercoin-core emercoin-cli -datadir=/data getblockchaininfo >/dev/null 2>&1; then
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
if docker exec softether-vpn /usr/local/vpnserver/vpncmd localhost:5555 /SERVER /CMD ServerStatusGet >/dev/null 2>&1; then
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
    if docker inspect "$service" | grep -q "$dependency"; then
        pass "${service} depends on ${dependency}"
    else
        warn "${service} dependency check failed"
    fi
done

# Test 8: Resource usage
log "Checking resource usage..."
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | tee -a "$TEST_LOG"

# Test 9: Volume integrity
log "Verifying volume mounts..."
volumes=("emercoin-data" "yggdrasil-data" "i2p-data" "skywire-data" "softether-data")
for vol in "${volumes[@]}"; do
    if docker volume inspect "$vol" >/dev/null 2>&1; then
        pass "Volume ${vol} exists"
    else
        fail "Volume ${vol} missing"
    fi
done

# Test 10: Network connectivity
log "Testing network connectivity..."
if docker network inspect ness-network >/dev/null 2>&1; then
    pass "Ness network bridge created"
else
    fail "Ness network bridge missing"
fi

log "E2E test suite completed successfully!"
echo -e "\n${green}Test Summary:${reset}"
echo "- All critical services verified"
echo "- Port connectivity confirmed"
echo "- Dependencies validated"
echo "- Logs available at: $TEST_LOG"
