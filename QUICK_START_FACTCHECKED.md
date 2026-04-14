# NESS Network Quick Start Guide - Fact-Checked Version

Get a privacy-focused mesh node running in minutes, not hours.

**Last verified**: 2026-03-07  
**NESS Version**: v0.5.0  
**Maintainer**: Jeff Bouchard (https://github.com/Jeff-Bouchard/)

---

## 1-Minute TL;DR

```bash
# Clone repository
git clone https://github.com/Jeff-Bouchard/ness.hub.docker.com.git
cd ness.hub.docker.com

# Copy configuration template
cp .env.example .env

# Deploy minimal stack (Emercoin + DNS reverse proxy)
docker compose -f docker-compose.minimal.yml up -d

# Verify running services
docker ps
```

**What's running**: Emercoin blockchain syncing + DNS private resolver + Privateness core blockchain

---

## Choose Your Deployment Profile

### Profile 1: Minimal (2GB disk, ~512MB RAM)
**Ideal for**: Testing, resource-constrained devices (Raspberry Pi 3+), proof-of-concept

```bash
docker compose -f docker-compose.minimal.yml up -d
```

**Actual services**:
- `emercoin-core` — Emercoin blockchain node with AuxPoW anchoring to Bitcoin
  - Port 6661/TCP: P2P blockchain protocol
  - Port 6662/TCP: JSON-RPC API (cookie-authenticated)
- `yggdrasil` — Yggdrasil IPv6 mesh network overlay
  - Port 9001/UDP: Mesh protocol
- `privateness` — NESS blockchain implementation (Skycoin fork)
  - Port 6006/TCP: P2P protocol
  - Port 6660/TCP: JSON-RPC API

**Verify**:
```bash
docker compose -f docker-compose.minimal.yml ps
docker logs emercoin-core              # Check Emercoin sync
docker logs privateness                # Check Privateness status
```

**Shutdown** (data persists):
```bash
docker compose -f docker-compose.minimal.yml down
```

---

### Profile 2: NESS Essential (5GB disk, ~1.5GB RAM) — **RECOMMENDED**
**Ideal for**: Production nodes, file privacy, decentralized DNS, entropy control

Includes all of Minimal, plus:

- `pyuheprng-privatenesstools` — Ultra-high entropy PRNG + cryptographic tools
  - Port 5000/TCP: pyuheprng HTTP API (entropy service)
  - Port 8888/TCP: Privateness CLI tools API
  - **Fact**: Feeds `/dev/random` directly with RC4OK (Emercoin) + hardware entropy + UHEPRNG (Gibson)
- `dns-reverse-proxy` — Decentralized DNS resolver on Emercoin NVS
  - Port 53/UDP+TCP: DNS resolver (listens on 1053 host-side by default)
  - Port 8053/TCP: HTTP control/metrics API
  - **Fact**: Uses EmerDNS for WORM-schema DNS entries; hybrid mode falls back to Cloudflare/Google DNS
- `ipfs` — InterPlanetary File System daemon
  - Port 4001/TCP: P2P swarm
  - Port 5001/TCP: API
  - Port 8080/TCP: Gateway (public-read, no write)

```bash
docker compose -f docker-compose.ness.yml up -d
```

**Verify Essential services**:
```bash
docker compose -f docker-compose.ness.yml ps
docker logs -f pyuheprng-privatenesstools      # Monitor entropy
docker exec pyuheprng-privatenesstools curl http://127.0.0.1:5000/health
docker exec dns-reverse-proxy curl http://127.0.0.1:8053/api/status
```

**Shutdown**:
```bash
docker compose -f docker-compose.ness.yml down
```

---

### Profile 3: Full Network (15GB disk, 4GB+ RAM)
**Ideal for**: Research, full mesh operator, multi-protocol testing

Includes all of Essential, plus:

- `i2p-yggdrasil` — Invisible Internet Protocol (I2P) over Yggdrasil mesh
  - Port 7657/TCP: I2P web console
  - Port 4444/TCP: HTTP proxy (via I2P)
  - Port 6668/TCP: IRC tunnel
  - **Fact**: I2P runs in "Yggdrasil-only" mode (no clearnet)
- `skywire` — Skycoin mesh visor (label-based MPLS-style routing)
  - Port 8000/TCP: Visor management UI
  - **Fact**: Uses Skycoin 100% uptime incentive model; not a secondary network
- `softether` — SoftEther stealth VPN (WireGuard with obfuscation)
  - Port 443/UDP: VPN endpoint

```bash
docker compose -f docker-compose.yml up -d
```

**Verify all services**:
```bash
docker compose ps
docker compose logs -f
```

**Shutdown**:
```bash
docker compose down
```

---

## Common Operations

### Monitor All Services (Real-Time)
```bash
# Global logs (all containers)
docker compose logs -f

# Single service logs
docker compose logs -f emercoin-core
docker compose logs -f pyuheprng-privatenesstools
docker compose logs -f dns-reverse-proxy
docker compose logs -f yggdrasil
```

### Check Service Health
```bash
# Docker status
docker ps

# Network connectivity
docker network inspect ness-network

# Individual container inspection
docker inspect emercoin-core | grep -A 10 '"Networks"'
docker inspect privateness | grep IPAddress
```

### Restart Individual Services
```bash
docker compose restart emercoin-core
docker compose restart privateness
docker compose restart pyuheprng-privatenesstools
docker compose restart dns-reverse-proxy
```

### Build Images Locally (from source)
```bash
# Single image
docker build -t nessnetwork/emercoin-core:latest ./emercoin-core
docker compose up -d emercoin-core

# All images (see build-all.sh)
bash build-all.sh
```

### Run CLI Tools Inside Containers
```bash
# Privateness blockchain status
docker exec privateness privateness-cli status

# Emercoin blockchain info
docker exec emercoin-core emercoin-cli -datadir=/data getblockchaininfo

# pyuheprng entropy statistics
docker exec pyuheprng-privatenesstools curl http://127.0.0.1:5000/status

# DNS proxy health check
docker exec dns-reverse-proxy curl http://127.0.0.1:8053/api/health
```

### Persistent Data (Volumes)
Data automatically persists across container restarts:
- `emercoin-data` — Emercoin blockchain (~1-2GB, grows with Bitcoin AuxPoW anchor chain)
- `ipfs-data` — IPFS stored content (~0-50GB, configurable)
- `yggdrasil-data` — Yggdrasil node state (~10MB)
- `i2p-data` — I2P router database (~100MB)

**Manual backup**:
```bash
docker run --rm -v emercoin-data:/data -v $(pwd):/backup \
  alpine tar czf /backup/emercoin-backup.tar.gz -C /data .
```

---

## Port Mappings (Fact-Checked)

### Minimal Stack Ports
| Service | Host Port | Container Port | Protocol | Purpose |
|---------|-----------|----------------|----------|---------|
| emercoin-core | 6661 | 6661 | TCP | P2P blockchain peer protocol (AuxPoW) |
| emercoin-core | 6662 | 6662 | TCP | JSON-RPC API (requires cookie auth) |
| yggdrasil | 9001 | 9001 | UDP | Yggdrasil mesh protocol (IPv6) |
| privateness | 6006 | 6006 | TCP | P2P protocol (Skycoin-based) |
| privateness | 6660 | 6660 | TCP | JSON-RPC API |

### NESS Essential Additional Ports
| Service | Host Port | Container Port | Protocol | Purpose |
|---------|-----------|----------------|----------|---------|
| pyuheprng | 5000 | 5000 | TCP | HTTP entropy service (/health, /rate, /sources) |
| privatenesstools | 8888 | 8888 | TCP | Privateness CLI tools API |
| dns-reverse-proxy | 1053 | 53 | UDP | DNS resolver (default host-side port 1053) |
| dns-reverse-proxy | 1053 | 53 | TCP | DNS resolver (TCP fallback) |
| dns-reverse-proxy | 8053 | 8053 | TCP | DNS HTTP control API |
| ipfs | 4001 | 4001 | TCP | IPFS P2P swarm |
| ipfs | 5001 | 5001 | TCP | IPFS HTTP API (admin access) |
| ipfs | 8080 | 8080 | TCP | IPFS gateway (public read-only) |

### Full Stack Additional Ports
| Service | Host Port | Container Port | Protocol | Purpose |
|---------|-----------|----------------|----------|---------|
| i2p-yggdrasil | 7657 | 7657 | TCP | I2P web console (router/tunnels) |
| i2p-yggdrasil | 4444 | 4444 | TCP | I2P HTTP proxy |
| skywire | 8000 | 8000 | TCP | Skywire visor management UI |
| softether | 443 | 443 | UDP | SoftEther VPN endpoint |

**Customize ports** in `.env`:
```bash
EMERCOIN_PORT_RPC=6662
PRIVATENESS_PORT_RPC=6660
DNS_PORT_UDP=53
YGGDRASIL_PORT=9001
SKYWIRE_PORT=8000
PYUHEPRNG_PORT=5000
```

After editing `.env`:
```bash
docker compose down
docker compose up -d
```

---

## Troubleshooting (Fact-Based)

### Container Exits Immediately
```bash
docker logs <container-name>
```
**Common causes**:
- Missing `.env` file → Copy `.env.example` to `.env`
- Port conflict → Change port in `.env`
- Insufficient disk space → `docker system df`
- Missing network → Re-run `docker compose up -d`

### Port Already in Use
```bash
# Linux/macOS
lsof -i :6661

# Windows
Get-NetTCPConnection -LocalPort 6661 | select ProcessName

# Solution: Change port in .env or stop conflicting process
```

### Out of Disk Space
```bash
docker system df              # Show usage
docker system prune -a        # Remove unused images/containers
docker volume prune           # Remove unused volumes
docker volume rm emercoin-data # Remove specific volume (WARNING: data loss)
```

### High Memory Usage
```bash
docker stats                  # Real-time resource usage

# Set limits in docker-compose.yml:
services:
  emercoin-core:
    mem_limit: 2g            # Max 2GB
    memswap_limit: 2g        # No swap beyond limit
```

### Container Keeps Restarting
```bash
docker inspect <container> | grep -A 5 '"State"'  # Check exit code
docker logs <container> --tail 100                  # Last 100 lines
```

---

## Security Notes (Fact-Checked)

### Network Isolation
- All containers run on isolated bridge network: `ness-network`
- No direct internet access (unless explicitly exposed via port mapping)
- Traffic between containers is encrypted by overlay protocols (Yggdrasil, Skywire, etc.)

### Authentication
- **Emercoin RPC**: Uses cookie-based auth (`/data/.cookie`), browser-inaccessible
- **IPFS API (port 5001)**: No auth by default → **Restrict to localhost only**
- **DNS proxy (port 8053)**: No auth → **Restrict to localhost**

### Privileged Containers
Only `pyuheprng-privatenesstools` runs in privileged mode (requires `/dev/random` access):
```bash
docker inspect pyuheprng-privatenesstools | grep Privileged
```

All others run unprivileged.

### Data Ownership
Files in volumes are owned by container UID (often UID 1000 for `ness` user):
```bash
docker run --rm -v emercoin-data:/data alpine ls -la /data
```

### Change RPC Credentials
```bash
# Edit .env
EMERCOIN_USER=newuser
EMERCOIN_PASS=$(openssl rand -base64 32)
PRIVATENESS_USER=newuser
PRIVATENESS_PASS=$(openssl rand -base64 32)

# Restart
docker compose down
docker compose up -d
```

---

## Environment Variables Reference

```bash
# Blockchain Configuration
EMERCOIN_PORT_P2P=6661              # Peer-to-peer protocol port
EMERCOIN_PORT_RPC=6662              # JSON-RPC API port
EMERCOIN_USER=rpcuser               # RPC authentication username
EMERCOIN_PASS=rpcpassword           # RPC authentication password

# Mesh Networks
YGGDRASIL_PORT=9001                 # Yggdrasil UDP port
SKYWIRE_PORT=8000                   # Skywire visor port

# Privacy Services
PRIVATENESS_PORT_P2P=6006           # Privateness P2P port
PRIVATENESS_PORT_RPC=6660           # Privateness JSON-RPC port
PYUHEPRNG_PORT=5000                 # Entropy service port
PRIVATENESSTOOLS_PORT=8888          # Tools API port

# DNS Configuration
DNS_PORT_UDP=53                      # DNS UDP listener
DNS_PORT_TCP=53                      # DNS TCP listener
DNS_API_PORT=8053                    # DNS HTTP control port

# Resource Limits (Optional)
EMERCOIN_MEM_LIMIT=2g               # Emercoin max memory
YGGDRASIL_MEM_LIMIT=512m            # Yggdrasil max memory
```

Restart after changes:
```bash
docker compose down
docker compose up -d
```

---

## Next Steps

1. **Run the Control Panel**:
   ```bash
   bash nessv0.5.sh
   ```
   Full menu for: profiles, DNS modes, service control, health checks, testing

2. **Open Web Dashboard**:
   ```bash
   http://localhost:6662/ness-dashboard-v0.5.0.html
   ```
   Real-time service monitoring

3. **Read Technical Documentation**:
   - [SERVICES.md](./doc/SERVICES.md) — Each service in detail
   - [NETWORK-ARCHITECTURE.md](./doc/NETWORK-ARCHITECTURE.md) — How traffic flows
   - [CRYPTOGRAPHIC-SECURITY.md](./doc/CRYPTOGRAPHIC-SECURITY.md) — Security bedrock (OWF + EmerNVS)

4. **Join the Mesh**:
   - Skywire: Share your visor public key with peers
   - Yggdrasil: Node automatically discoverable by IPv6 address
   - I2P: Router identity persisted in `/var/lib/i2p/router.info`

5. **Use PrivatenessTools**:
   ```bash
   docker exec pyuheprng-privatenesstools privateness-cli --help
   # Encrypt files → IPFS → Decentralized backup
   ```

---

## Getting Help

- **GitHub Issues**: https://github.com/Jeff-Bouchard/ness.hub.docker.com/issues
- **NESS Network Docs**: See `./doc/` directory
- **Docker Docs**: https://docs.docker.com/compose/reference/

---

## Cleanup & Shutdown

**Graceful shutdown** (data preserved):
```bash
docker compose down
```

**Shutdown + remove volumes** (delete all data):
```bash
docker compose down -v
```

**Full cleanup** (remove images too):
```bash
docker compose down -v --rmi all
```

---

**Happy networking!**

**Document version**: 0.5.0-factchecked  
**Last updated**: 2026-03-07  
**Verified by**: Jeff Bouchard (NESS maintainer)
