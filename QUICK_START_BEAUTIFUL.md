# 🌐 NESS Network Quick Start Guide
## Get Privacy-Focused Mesh Running in Minutes

> **Status**: Production Ready | **Version**: v0.5.0 | **Languages**: English · Français (QC)

---

## 🚀 1-Minute Quick Start

```bash
# Clone the repository
git clone https://github.com/Jeff-Bouchard/ness.hub.docker.com.git
cd ness.hub.docker.com

# Copy configuration
cp .env.example .env

# Deploy and run
docker compose -f docker-compose.minimal.yml up -d

# Verify
docker ps
```

**What's Running?** Emercoin blockchain + DNS resolver + Privateness core

---

## 📦 Choose Your Deployment

### 🟢 **Minimal** — Testing & Low Resources
```
💾 ~2GB disk  |  🖥️ ~512MB RAM  |  ⏱️ 5 minutes
```

Perfect for:
- Testing the stack
- Raspberry Pi 3+
- Proof of concept

**Deploy:**
```bash
docker compose -f docker-compose.minimal.yml up -d
```

**Services:**
- 🔗 **emercoin-core** — Blockchain node (AuxPoW anchored to Bitcoin)
  - `6661/TCP` → P2P protocol
  - `6662/TCP` → JSON-RPC API
- 🕸️ **yggdrasil** — IPv6 mesh overlay
  - `9001/UDP` → Mesh protocol
- 🔐 **privateness** — NESS blockchain (Skycoin-based)
  - `6006/TCP` → P2P protocol
  - `6660/TCP` → JSON-RPC API

**Check Status:**
```bash
docker compose -f docker-compose.minimal.yml ps
docker logs emercoin-core
```

---

### 🟡 **Essential** — Recommended for Production ⭐
```
💾 ~5GB disk  |  🖥️ ~1.5GB RAM  |  ⏱️ 10 minutes
```

Perfect for:
- Production privacy nodes
- Encrypted file storage
- Decentralized DNS
- Entropy control

**Deploy:**
```bash
docker compose -f docker-compose.ness.yml up -d
```

**Includes Everything from Minimal, Plus:**

- 🎲 **pyuheprng-privatenesstools** — Ultra-high entropy PRNG
  - `5000/TCP` → Entropy service (`/health`, `/rate`, `/sources`)
  - `8888/TCP` → Privateness CLI tools API
  - ✨ Feeds `/dev/random` with RC4OK + hardware entropy + UHEPRNG

- 🔍 **dns-reverse-proxy** — Decentralized DNS on Emercoin
  - `1053/UDP+TCP` → DNS resolver (host-side default port)
  - `8053/TCP` → HTTP control/metrics API
  - 🌍 Uses EmerDNS for WORM-schema entries; hybrid mode falls back to Cloudflare/Google

- 📦 **ipfs** — Decentralized file storage
  - `4001/TCP` → P2P swarm
  - `5001/TCP` → HTTP API
  - `8080/TCP` → Public gateway (read-only)

**Check Status:**
```bash
docker compose -f docker-compose.ness.yml ps
docker logs -f pyuheprng-privatenesstools
```

---

### 🔴 **Full Stack** — Complete Mesh Infrastructure
```
💾 ~15GB disk  |  🖥️ ~4GB RAM  |  ⏱️ 15 minutes
```

Perfect for:
- Research & development
- Full mesh operator
- Multi-protocol testing

**Deploy:**
```bash
docker compose -f docker-compose.yml up -d
```

**Includes Everything from Essential, Plus:**

- 👁️ **i2p-yggdrasil** — Anonymous routing over mesh
  - `7657/TCP` → I2P web console
  - `4444/TCP` → HTTP proxy
  - 🔒 I2P runs in "Yggdrasil-only" mode (no clearnet)

- 🕸️ **skywire** — MPLS mesh routing (Skycoin protocol)
  - `8000/TCP` → Visor management UI
  - 💰 Uses Skycoin 100% uptime incentive model

- 🔓 **amneziawg** — Stealth VPN with obfuscation
  - `51820/UDP` → VPN endpoint
  - 👻 WireGuard with DPI bypass

---

## 🎮 Common Operations

### 📺 Monitor Everything

```bash
# Real-time all services
docker compose logs -f

# Watch specific service
docker compose logs -f emercoin-core
docker compose logs -f pyuheprng-privatenesstools
docker compose logs -f dns-reverse-proxy
```

### ✅ Check Health

```bash
# Running containers
docker ps

# Network isolation
docker network inspect ness-network

# Entropy status
curl http://localhost:5000/health
curl http://localhost:5000/sources

# DNS status
curl http://localhost:8053/api/health
```

### 🔄 Restart Services

```bash
docker compose restart emercoin-core
docker compose restart privateness
docker compose restart pyuheprng-privatenesstools
```

### 🏗️ Rebuild Locally

```bash
# Single image from source
docker build -t nessnetwork/emercoin-core:latest ./emercoin-core
docker compose up -d emercoin-core

# All images
bash build-all.sh
```

### 💾 Access Tools Inside

```bash
# Privateness status
docker exec privateness privateness-cli status

# Emercoin blockchain info
docker exec emercoin-core emercoin-cli -datadir=/data getblockchaininfo

# Entropy statistics
docker exec pyuheprng-privatenesstools curl http://127.0.0.1:5000/status
```

### 💾 Backup Data

Data automatically persists in volumes:
- **emercoin-data** → ~1-2GB (grows with Bitcoin AuxPoW history)
- **ipfs-data** → 0-50GB (configurable)
- **yggdrasil-data** → ~10MB (mesh state)
- **i2p-data** → ~100MB (router database)

**Create Backup:**
```bash
docker run --rm -v emercoin-data:/data -v $(pwd):/backup \
  alpine tar czf /backup/ness-backup.tar.gz -C /data .
```

---

## 🔌 Port Reference

### Minimal Stack

| Service | Port | Protocol | Purpose |
|---------|------|----------|---------|
| 🔗 emercoin-core | `6661` | TCP | P2P blockchain |
| 🔗 emercoin-core | `6662` | TCP | JSON-RPC API |
| 🕸️ yggdrasil | `9001` | UDP | Mesh network |
| 🔐 privateness | `6006` | TCP | P2P protocol |
| 🔐 privateness | `6660` | TCP | JSON-RPC API |

### Essential Stack (adds)

| Service | Port | Protocol | Purpose |
|---------|------|----------|---------|
| 🎲 pyuheprng | `5000` | TCP | Entropy service |
| 🛠️ privatenesstools | `8888` | TCP | Tools API |
| 🔍 dns-proxy | `1053` | UDP/TCP | DNS resolver |
| 🔍 dns-proxy | `8053` | TCP | HTTP control |
| 📦 ipfs | `4001` | TCP | P2P swarm |
| 📦 ipfs | `5001` | TCP | API |
| 📦 ipfs | `8080` | TCP | Gateway |

### Full Stack (adds)

| Service | Port | Protocol | Purpose |
|---------|------|----------|---------|
| 👁️ i2p | `7657` | TCP | Web console |
| 👁️ i2p | `4444` | TCP | HTTP proxy |
| 🕸️ skywire | `8000` | TCP | Visor UI |
| 🔓 amneziawg | `51820` | UDP | VPN |

**Customize in `.env`:**
```bash
EMERCOIN_PORT_RPC=6662
PRIVATENESS_PORT_RPC=6660
DNS_PORT_UDP=53
YGGDRASIL_PORT=9001
```

Restart after changes:
```bash
docker compose down
docker compose up -d
```

---

## 🔧 Configuration

### Environment Variables

Create `.env` (copy from `.env.example`):

```bash
# ═══════════ Blockchain ═══════════
EMERCOIN_PORT_P2P=6661
EMERCOIN_PORT_RPC=6662
EMERCOIN_USER=rpcuser
EMERCOIN_PASS=rpcpassword

# ═════════ Mesh Networks ═════════
YGGDRASIL_PORT=9001
SKYWIRE_PORT=8000

# ════════ Privacy Services ════════
PRIVATENESS_PORT_P2P=6006
PRIVATENESS_PORT_RPC=6660
PYUHEPRNG_PORT=5000
PRIVATENESSTOOLS_PORT=8888

# ══════════ DNS Config ══════════
DNS_PORT_UDP=53
DNS_PORT_TCP=53
DNS_API_PORT=8053

# ════════ Resource Limits ════════
EMERCOIN_MEM_LIMIT=2g
YGGDRASIL_MEM_LIMIT=512m
```

Apply changes:
```bash
docker compose down
docker compose up -d
```

---

## 🚨 Troubleshooting

### 🔴 Container Exits Immediately

```bash
docker logs <container-name>
```

**Common Causes:**
- ❌ Missing `.env` → Copy `.env.example` to `.env`
- ❌ Port conflict → Change in `.env`
- ❌ No disk space → `docker system df`
- ❌ Network issue → Re-run `docker compose up -d`

---

### 🔴 Port Already in Use

```bash
# Find what's using the port
lsof -i :6661              # Linux/macOS
Get-NetTCPConnection -LocalPort 6661 | select ProcessName  # Windows

# Fix: Change port in .env and restart
```

---

### 🔴 Out of Disk Space

```bash
# Check usage
docker system df

# Clean up unused
docker system prune -a

# Delete specific volume (⚠️ data loss)
docker volume rm emercoin-data
```

---

### 🔴 High Memory Usage

```bash
# Check stats
docker stats

# Set limits in docker-compose.yml
services:
  emercoin-core:
    mem_limit: 2g
    memswap_limit: 2g
```

---

### 🔴 Container Keeps Restarting

```bash
# Check exit code
docker inspect <container> | grep -A 5 '"State"'

# View logs
docker logs <container> --tail 100
```

---

## 🔒 Security

### Network Isolation
✅ All containers on isolated bridge network (`ness-network`)  
✅ No direct internet access (unless mapped)  
✅ Traffic encrypted by overlay protocols

### Authentication
- 🔐 **Emercoin RPC**: Cookie-based auth (browser-inaccessible)
- 🔐 **IPFS API**: No auth → **Restrict to localhost**
- 🔐 **DNS proxy**: No auth → **Restrict to localhost**

### Privileged Mode
⚠️ Only `pyuheprng-privatenesstools` runs privileged (needs `/dev/random` access)

### Change RPC Credentials

```bash
# Edit .env
EMERCOIN_USER=newuser
EMERCOIN_PASS=$(openssl rand -base64 32)

# Restart
docker compose down
docker compose up -d
```

---

## 🎓 Next Steps

### 1️⃣ Run the Control Panel
```bash
bash nessv0.5.sh
```
Full menu for profiles, DNS modes, service control, health checks

### 2️⃣ Open Web Dashboard
```
http://localhost:6662/ness-dashboard-v0.5.0.html
```
Real-time service monitoring

### 3️⃣ Read Technical Docs
- 📘 **SERVICES.md** — Each service in detail
- 📘 **NETWORK-ARCHITECTURE.md** — How traffic flows
- 📘 **CRYPTOGRAPHIC-SECURITY.md** — Security bedrock

### 4️⃣ Join the Mesh
- Share your Skywire public key
- IPv6 address automatically discoverable
- Persist router identity

### 5️⃣ Use PrivatenessTools
```bash
docker exec pyuheprng-privatenesstools privateness-cli --help
```
Encrypt files → IPFS → Decentralized backup

---

## 🛑 Shutdown & Cleanup

### Stop All Services (data persists)
```bash
docker compose down
```

### Stop & Remove Data
```bash
docker compose down -v
```

### Complete Cleanup (remove images too)
```bash
docker compose down -v --rmi all
```

---

## 📚 Getting Help

| Resource | Link |
|----------|------|
| **GitHub Issues** | https://github.com/Jeff-Bouchard/ness.hub.docker.com/issues |
| **Documentation** | `./doc/` folder |
| **Docker Docs** | https://docs.docker.com/compose/reference/ |

---

<div align="center">

### 🌟 Happy Privacy Networking! 🌟

**Version**: 0.5.0 | **Updated**: March 7, 2026 | **Status**: ✅ Production Ready

</div>
