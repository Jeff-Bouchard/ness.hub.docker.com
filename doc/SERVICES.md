# Privateness Network Services

[Français](SERVICES-FR.md)

Complete list of all services in the privateness.network stack.

## Core Services

### 1. Emercoin Core
**Blockchain foundation**
- Decentralized naming (NVS)
- RC4OK entropy source
- Service discovery
- Port: 6661 (P2P), 6662 (JSON-RPC)

### 2. Privateness
**Core application**
- Network coordination
- Service management
- Ports: 6006 (P2P), 6660 (JSON-RPC)

### 3. DNS Reverse Proxy
**Decentralized DNS**
- Emercoin NVS resolution
- Traditional DNS fallback
- Port: 53 (UDP/TCP), 8053 (HTTP)

## Cryptographic Security

### 4. pyuheprng
**Entropy generation**
- Feeds `/dev/random` directly
- RC4OK + Hardware + UHEP sources
- Eliminates entropy deprivation
- Port: 5000

### 5. pyuheprng-privatenesstools (Combined)
**Entropy + Tools**
- pyuheprng (port 5000)
- privatenesstools (port 8888)
- Resource-efficient combination

## Mesh Networking

### 6. Skywire
**MPLS mesh routing**
- Decentralized routing
- Multi-path selection
- Label-based forwarding in mesh core instead of ordinary IP routing
- Port: 8000

### 7. Yggdrasil
**IPv6 mesh overlay**
- Encrypted mesh network
- DHT-based routing
- End-to-end encryption
- Port: 9001

### 8. I2P (Yggdrasil Mode)
**Anonymous network**
- Garlic routing
- Routes through Yggdrasil
- Layered encryption
- Ports: 7657 (HTTP), 4444 (SOCKS), 6668 (IRC)

## Access Layer

### 9. AmneziaWG
**Stealth VPN**
- Obfuscated WireGuard
- DPI bypass
- Undetectable VPN
- Port: 51820 (UDP)

### 10. Skywire-AmneziaWG
**Access → Mesh integration**
- AmneziaWG access layer
- Routes to Skywire mesh
- Complete privacy stack
- Ports: 8001 (Skywire), 51821 (AmneziaWG)

## Storage & Content

### 11. IPFS
**Decentralized storage**
- Content-addressed files
- Peer-to-peer distribution
- Integrates with Emercoin NVS
- Ports: 4001 (P2P), 5001 (API), 8080 (Gateway), 8081 (WebUI)

## Utility Services

### 12. privatenumer
**Private number generation**
- Secure random numbers
- Uses pyuheprng entropy
- Port: 3000

### 13. privatenesstools
**Network utilities**
- Management tools
- Network diagnostics
- Port: 8888

## All-in-One

### 14. ness-unified
**Complete stack in one container**
- All services combined
- For single-node deployment
- All ports exposed

## Service Dependencies

```
emercoin-core (foundation)
    ├─ yggdrasil
    │   └─ i2p-yggdrasil
    ├─ dns-reverse-proxy
    ├─ skywire
    ├─ pyuheprng
    │   ├─ privatenumer
    │   └─ privatenesstools
    └─ privateness
        └─ privatenesstools

ipfs (independent)
amneziawg (independent)
skywire-amneziawg (independent)
```

## Port Summary

| Service | Ports | Protocol |
|---------|-------|----------|
| emercoin-core | 6661, 6662 | TCP |
| privateness | 6006, 6660 | TCP |
| dns-reverse-proxy | 53, 8053 | UDP/TCP, HTTP |
| pyuheprng | 5000 | HTTP |
| privatenumer | 3000 | HTTP |
| privatenesstools | 8888 | HTTP |
| skywire | 8000 | HTTP |
| yggdrasil | 9001 | TCP/UDP |
| i2p-yggdrasil | 7657, 4444, 6668 | HTTP, SOCKS, IRC |
| ipfs | 4001, 5001, 8080, 8081 | P2P, API, Gateway, WebUI |
| amneziawg | 51820 | UDP |
| skywire-amneziawg | 8001, 51821 | HTTP, UDP |

## Resource Requirements

### Minimal Stack (Ness Essential)
- **Services**: emercoin-core, pyuheprng-privatenesstools, dns-reverse-proxy, privateness
- **RAM**: ~1.5GB
- **Disk**: ~10GB
- **CPU**: 2 cores minimum

### Full Stack
- **Services**: All 14 services
- **RAM**: ~4GB
- **Disk**: ~50GB (including IPFS storage)
- **CPU**: 4 cores recommended

### Pi4 Optimized
- **Services**: Minimal stack + IPFS
- **RAM**: ~2GB
- **Disk**: ~20GB
- **CPU**: Pi4 4GB/8GB model

## Network Architecture Layers

### Layer 1: Access
- AmneziaWG (stealth VPN entry)

### Layer 2: Transport
- Skywire (MPLS mesh routing)
- Yggdrasil (IPv6 mesh overlay)

### Layer 3: Network
- I2P (garlic routing)
- DNS Reverse Proxy (decentralized naming)

### Layer 4: Application
- Privateness (coordination)
- IPFS (storage)
- Emercoin (blockchain)

### Layer 5: Security
- pyuheprng (entropy)
- Binary verification (reproducible builds)
- Cryptographic properties (design goals)

## Use Cases by Service Combination

### Privacy Browsing
```
Client → AmneziaWG → Skywire → Yggdrasil → I2P → Internet
```
Services needed: amneziawg, skywire, yggdrasil, i2p-yggdrasil

### Decentralized Website Hosting
```
Website → IPFS → Emercoin NVS (naming) → DNS Proxy → Clients
```
Services needed: ipfs, emercoin-core, dns-reverse-proxy

### Secure File Sharing
```
File → IPFS (storage) → Emercoin (hash registry) → Privateness (coordination)
```
Services needed: ipfs, emercoin-core, privateness

### Mesh Networking
```
Node → Skywire (routing) → Yggdrasil (overlay) → Peer Nodes
```
Services needed: skywire, yggdrasil, emercoin-core

### Complete Privacy Stack
```
All services for maximum privacy and decentralization
```
Services needed: All 14 services

## Integration Examples

### IPFS + Emercoin
```bash
# Upload to IPFS
ipfs add file.txt
# QmXxx...

# Register in blockchain
emercoin-cli name_new "ipfs:myfile" "QmXxx..."

# Resolve via DNS
dig ipfs.myfile.emc TXT
```

### Skywire + AmneziaWG
```bash
# Client connects via AmneziaWG
# Traffic automatically routes through Skywire mesh
# Exit via decentralized mesh nodes
```

### I2P + Yggdrasil
```bash
# I2P traffic routes through Yggdrasil IPv6 mesh
# Double encryption: I2P garlic + Yggdrasil tunnel
# Untraceable routing
```

## Monitoring All Services

```bash
# Check all services
docker-compose ps

# Check specific service
docker logs <service-name>

# Health checks
curl http://localhost:5000/health  # pyuheprng
curl http://localhost:8053/health  # dns-proxy
curl http://localhost:5001/api/v0/id  # ipfs
```

## Backup Strategy

### Critical Data
- Emercoin blockchain: `/data/emercoin`
- IPFS content: `/data/ipfs`
- Yggdrasil keys: `/etc/yggdrasil`
- AmneziaWG config: `/etc/amneziawg`

### Backup Command
```bash
docker run --rm \
  -v emercoin-data:/emercoin \
  -v ipfs-data:/ipfs \
  -v $(pwd):/backup \
  alpine tar czf /backup/ness-backup.tar.gz /emercoin /ipfs
```

## Security Considerations

### Binary Equivalence
All services must use verified binaries (see REPRODUCIBLE-BUILDS.md)

### Entropy Security
pyuheprng must run with privileged mode (see CRYPTOGRAPHIC-SECURITY.md)

### Network Isolation
Services communicate via Docker network, isolated from host

### Access Control
Portainer labels enable team-based access control

## Performance Tuning

### High-Traffic Nodes
- Increase Skywire connection limits
- Enable IPFS accelerated DHT
- Optimize I2P tunnel count

### Resource-Constrained Devices
- Use minimal stack
- Reduce IPFS storage limit
- Disable unused services

### Production Deployment
- Enable all health checks
- Configure automatic restarts
- Set up monitoring alerts
- Implement backup automation

## Documentation Links

- [CRYPTOGRAPHIC-SECURITY.md](CRYPTOGRAPHIC-SECURITY.md) - Entropy and security
- [REPRODUCIBLE-BUILDS.md](REPRODUCIBLE-BUILDS.md) - Binary verification
- [INCENTIVE-SECURITY.md](INCENTIVE-SECURITY.md) - Economic security
- [NETWORK-ARCHITECTURE.md](NETWORK-ARCHITECTURE.md) - Protocol hopping
- [PORTAINER.md](PORTAINER.md) - Deployment guide
- [DEPLOY.md](DEPLOY.md) - Docker Hub deployment

## Support

For service-specific documentation, see README.md in each service directory:
- `emercoin-core/README.md`
- `ipfs/README.md`
- `pyuheprng/README.md`
- `amneziawg/README.md`
- etc.

For external specifications (Emercoin services, overlay networks, RNG behavior, etc.), see:

- `SOURCES.md` at the repository root

