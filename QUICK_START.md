# NESS Network Quick Start Guide

Get a privacy-focused mesh node running in minutes, not hours.

## 1-Minute TL;DR

```bash
# Clone repo
git clone https://github.com/Jeff-Bouchard/ness.hub.docker.com.git
cd ness.hub.docker.com

# Copy config
cp .env.example .env

# Start minimal stack (emercoin + dns-proxy)
docker compose -f docker-compose.minimal.yml up -d

# Check status
docker ps
```

That's it. Emercoin is syncing, DNS is resolving privately.

---

## Choose Your Path

### Path 1: Minimal (2GB, Pi4 Compatible)
**For**: Testing, minimal footprint, DNS + blockchain only

```bash
docker compose -f docker-compose.minimal.yml up -d
```

**Services started:**
- `emercoin-core` — Blockchain node (6661, 6662)
- `yggdrasil` — Mesh network (9001)
- `privateness` — Core blockchain (6006, 6660)

**Check status:**
```bash
docker compose -f docker-compose.minimal.yml ps
docker logs emercoin-core
```

**Stop:**
```bash
docker compose -f docker-compose.minimal.yml down
```

---

### Path 2: NESS Essential (5GB, Recommended)
**For**: Privacy files, mesh routing, entropy control

Includes everything from Minimal plus:
- `pyuheprng-privatenesstools` — Cryptographic entropy + file tools (5000, 8888)
- `dns-reverse-proxy` — Decentralized DNS (53, 8053)
- `ipfs` — Content storage (4001, 5001, 8080)

```bash
docker compose -f docker-compose.ness.yml up -d
```

**Check status:**
```bash
docker compose -f docker-compose.ness.yml ps
docker logs -f pyuheprng-privatenesstools
```

**Access PrivatenessTools CLI:**
```bash
docker exec pyuheprng-privatenesstools privateness-cli --help
```

**Stop:**
```bash
docker compose -f docker-compose.ness.yml down
```

---

### Path 3: Full Network (15GB, Requires 4GB+ RAM)
**For**: Complete mesh infrastructure with all routing protocols

Includes everything from Essential plus:
- `i2p-yggdrasil` — I2P + Yggdrasil (7657, 4444, 6668)
- `skywire` — Skycoin mesh visor (8000)
- `amneziawg` — Stealth VPN layer (51820)

```bash
docker compose -f docker-compose.yml up -d
```

**Check all services:**
```bash
docker compose ps
```

**Stop:**
```bash
docker compose down
```

---

## Common Operations

### View Real-Time Logs
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f emercoin-core
docker compose logs -f pyuheprng-privatenesstools
docker compose logs -f dns-reverse-proxy
```

### Check Network Status
```bash
# Running containers
docker ps

# Network connectivity
docker network inspect ness-network
docker inspect emercoin-core | grep -A 10 '"Networks"'
```

### Restart a Service
```bash
docker compose restart emercoin-core
docker compose restart pyuheprng-privatenesstools
```

### Rebuild Image Locally
```bash
# Rebuild specific image (from source)
docker build -t nessnetwork/emercoin-core:latest ./emercoin-core
docker compose up -d
```

### Execute Commands in Container
```bash
# Run privateness CLI
docker exec privateness privateness-cli status

# Run emercoin CLI
docker exec emercoin-core emercoin-cli -datadir=/data getinfo

# Get entropy stats
docker exec pyuheprng-privatenesstools curl http://localhost:5000/status
```

### Persist Data Across Restarts
Data is already persisted in Docker volumes:
- `emercoin-data` — Blockchain state (~1-2GB)
- `ipfs-data` — IPFS storage (~configurable)
- `yggdrasil-data` — Mesh network state
- `i2p-data` — I2P node state

To backup:
```bash
docker run --rm -v emercoin-data:/data -v $(pwd):/backup \
  alpine tar czf /backup/emercoin-backup.tar.gz -C /data .
```

---

## Port Mappings & Configuration

### Minimal Stack
| Service | Port | Protocol | Purpose |
|---------|------|----------|---------|
| emercoin-core | 6661 | TCP | P2P blockchain |
| emercoin-core | 6662 | TCP | JSON-RPC API |
| yggdrasil | 9001 | UDP | Mesh network |
| privateness | 6006 | TCP | P2P |
| privateness | 6660 | TCP | JSON-RPC |

### NESS Essential Stack (adds)
| Service | Port | Protocol | Purpose |
|---------|------|----------|---------|
| pyuheprng | 5000 | TCP | Entropy service |
| privatenesstools | 8888 | TCP | File tools API |
| dns-proxy | 53 | UDP/TCP | DNS server |
| dns-proxy | 8053 | TCP | DNS API |
| ipfs | 4001 | TCP | IPFS P2P |
| ipfs | 5001 | TCP | IPFS API |
| ipfs | 8080 | TCP | IPFS Gateway |

### Full Stack (adds)
| Service | Port | Protocol | Purpose |
|---------|------|----------|---------|
| i2p | 7657 | TCP | I2P console |
| i2p | 4444 | TCP | HTTP proxy |
| skywire | 8000 | TCP | Visor API |
| amneziawg | 51820 | UDP | VPN |

**Customize ports** in `.env`:
```bash
# Edit .env
EMERCOIN_PORT_RPC=6662
PRIVATENESS_PORT_RPC=6660
DNS_PORT_UDP=53
# etc.

# Restart
docker compose down
docker compose up -d
```

---

## Troubleshooting

### Container exits immediately
```bash
docker logs <container-name>
# Check for missing dependencies or configuration errors
```

### Port already in use
```bash
# Find what's using port 6661
lsof -i :6661  # macOS/Linux
Get-NetTCPConnection -LocalPort 6661 | select ProcessName  # Windows

# Change port in .env and restart
```

### Out of disk space
```bash
# Check usage
docker system df

# Clean up (removes stopped containers & unused images)
docker system prune -a

# Remove specific volume
docker volume rm emercoin-data
```

### Slow performance / High memory
```bash
# Check resource usage
docker stats

# Limit memory for a service (in docker-compose.yml)
services:
  emercoin-core:
    mem_limit: 2g
    memswap_limit: 2g
```

### Container keeps restarting
```bash
# View last exit code
docker inspect <container> | grep ExitCode

# Read full logs
docker logs <container> --tail 100
```

---

## Security Notes

### Network Isolation
All containers run on an internal bridge network (`ness-network`). Port mappings are explicit in `docker-compose.yml`.

### File Permissions
Files in `emercoin-data` volume are owned by the container. To access:
```bash
docker run --rm -v emercoin-data:/data alpine ls -la /data
```

### Credentials
- **RPC user/pass**: Set in `.env` (default: `rpcuser` / `rpcpassword`)
- **Change them in production:**
```bash
# Edit .env
EMERCOIN_USER=myuser
EMERCOIN_PASS=myrandompassword
docker compose down && docker compose up -d
```

### Privileged Mode
Only `pyuheprng-privatenesstools` runs privileged (to feed `/dev/random`). No other services have elevated privileges.

---

## Environment Variables

Create a `.env` file (copy from `.env.example`):

```bash
# Blockchain
EMERCOIN_PORT_P2P=6661
EMERCOIN_PORT_RPC=6662
EMERCOIN_USER=rpcuser
EMERCOIN_PASS=rpcpassword

# Mesh networks
YGGDRASIL_PORT=9001
SKYWIRE_PORT=8000

# Privacy services
PRIVATENESS_PORT_P2P=6006
PRIVATENESS_PORT_RPC=6660
PYUHEPRNG_PORT=5000
PRIVATENESSTOOLS_PORT=8888

# DNS
DNS_PORT_UDP=53
DNS_PORT_TCP=53
DNS_API_PORT=8053

# Resource limits (optional)
EMERCOIN_MEM_LIMIT=2g
YGGDRASIL_MEM_LIMIT=512m
```

Then restart:
```bash
docker compose down
docker compose up -d
```

---

## Next Steps

1. **Read the documentation:**
   - [SERVICES.md](./doc/SERVICES.md) — All services explained
   - [NETWORK-ARCHITECTURE.md](./doc/NETWORK-ARCHITECTURE.md) — How traffic flows
   - [CRYPTOGRAPHIC-SECURITY.md](./doc/CRYPTOGRAPHIC-SECURITY.md) — Security model

2. **Join the mesh:**
   - Connect your node to the Ness network (see Skywire docs)
   - Share your node address to peers

3. **Use PrivatenessTools:**
   - Encrypt files to IPFS
   - Backup to decentralized storage
   - CLI: `docker exec pyuheprng-privatenesstools privateness-cli --help`

4. **Monitor your node:**
   - Dashboard: TBD
   - Stats: `docker stats`

---

## Getting Help

- **GitHub Issues:** https://github.com/Jeff-Bouchard/ness.hub.docker.com/issues
- **Discord:** TBD
- **Docs:** Full documentation in `doc/` folder

---

## Stopping & Cleanup

**Stop all services (data persists):**
```bash
docker compose down
```

**Stop and remove all data:**
```bash
docker compose down -v
```

**Remove everything (containers, images, volumes):**
```bash
docker compose down -v --rmi all
```

---

Happy networking!
