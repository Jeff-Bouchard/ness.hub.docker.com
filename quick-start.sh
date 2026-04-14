#!/bin/bash

# NESS Network Quick Start for Windows (Git Bash)
# Run: bash quick-start.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Check prerequisites
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        log_info "Install Docker Desktop from: https://www.docker.com/products/docker-desktop"
        exit 1
    fi
    
    if ! docker ps &> /dev/null; then
        log_error "Docker daemon is not running"
        log_info "Start Docker Desktop"
        exit 1
    fi
    
    log_success "Docker is installed and running"
}

check_docker_compose() {
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed"
        log_info "Install via: https://docs.docker.com/compose/install/"
        exit 1
    fi
    log_success "Docker Compose is available"
}

check_git() {
    if ! command -v git &> /dev/null; then
        log_error "Git is not installed"
        log_info "Install Git Bash from: https://git-scm.com/download/win"
        exit 1
    fi
    log_success "Git is installed"
}

# Clone or update repository
setup_repo() {
    local repo_url="https://github.com/Jeff-Bouchard/ness.hub.docker.com.git"
    local repo_dir="${NESS_HOME:-$HOME/ness-network}"
    
    log_info "Setting up repository at: $repo_dir"
    
    if [[ -d "$repo_dir/.git" ]]; then
        log_info "Repository exists, updating..."
        cd "$repo_dir"
        git pull origin master
    else
        log_info "Cloning repository..."
        git clone "$repo_url" "$repo_dir"
        cd "$repo_dir"
    fi
    
    log_success "Repository ready at: $repo_dir"
    echo "$repo_dir"
}

# Select deployment profile
select_profile() {
    log_info "Select deployment profile:"
    echo ""
    echo "  1) Minimal (emercoin-core + dns-proxy) - ~2GB, Pi4 compatible"
    echo "  2) Essential (minimal + privateness + pyuheprng) - ~5GB, Recommended"
    echo "  3) Full (all services) - ~15GB, requires 4GB+ RAM"
    echo ""
    read -p "Enter choice [1-3] (default: 2): " profile_choice
    profile_choice=${profile_choice:-2}
    
    case "$profile_choice" in
        1) echo "minimal" ;;
        2) echo "ness" ;;
        3) echo "full" ;;
        *) log_error "Invalid choice"; exit 1 ;;
    esac
}

# Deploy stack
deploy_stack() {
    local repo_dir="$1"
    local profile="$2"
    
    cd "$repo_dir"
    
    local compose_file="docker-compose.yml"
    case "$profile" in
        minimal) compose_file="docker-compose.minimal.yml" ;;
        ness) compose_file="docker-compose.ness.yml" ;;
        full) compose_file="docker-compose.yml" ;;
    esac
    
    if [[ ! -f "$compose_file" ]]; then
        log_error "Compose file not found: $compose_file"
        exit 1
    fi
    
    log_info "Deploying with profile: $profile ($compose_file)"
    
    # Copy .env.example if no .env exists
    if [[ ! -f .env ]]; then
        log_info "Creating .env from template..."
        cp .env.example .env
    fi
    
    log_info "Pulling latest images (this may take a few minutes)..."
    docker compose -f "$compose_file" pull
    
    log_info "Starting services..."
    docker compose -f "$compose_file" up -d
    
    log_success "Stack deployed successfully"
}

# Show status
show_status() {
    local repo_dir="$1"
    
    cd "$repo_dir"
    
    echo ""
    log_info "Service Status:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    echo ""
    log_info "Key endpoints:"
    echo "  - Emercoin RPC:       http://localhost:6662"
    echo "  - DNS Proxy:           localhost:53 (udp/tcp)"
    echo "  - Privateness P2P:     localhost:6006"
    echo "  - Privateness RPC:     http://localhost:6660"
    echo ""
    
    log_info "Next steps:"
    echo "  1. Check logs:    docker compose logs -f"
    echo "  2. Stop stack:    docker compose down"
    echo "  3. Documentation: $repo_dir/QUICK_START.md"
    echo ""
}

# Main flow
main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  NESS Network Quick Start              ║${NC}"
    echo -e "${BLUE}║  Privacy-First Mesh Infrastructure     ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""
    
    check_docker
    check_docker_compose
    check_git
    
    local repo_dir=$(setup_repo)
    local profile=$(select_profile)
    deploy_stack "$repo_dir" "$profile"
    show_status "$repo_dir"
    
    echo -e "${GREEN}✓ NESS Network is running!${NC}"
}

main "$@"
