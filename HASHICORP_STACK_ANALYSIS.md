# HashiCorp Stack vs Docker Compose Analysis for NESS Hub

## Executive Summary

| Aspect | Docker Compose (Current) | HashiCorp Stack (Nomad+Consul+Vault) |
|--------|------------------------|--------------------------------------|
| **Complexity** | Low - Single YAML file | High - 3 separate systems to maintain |
| **Node Count** | Optimized for single-node (Pi 3) | Designed for multi-node clusters |
| **Network Privileges** | Full `NET_ADMIN`, `SYS_MODULE`, tun devices | Limited - requires privileged drivers |
| **Secrets** | Env vars / volumes | Native Vault integration |
| **Service Discovery** | DNS aliases, links | Native Consul integration |
| **Decentralization** | Simple, portable | Central orchestration (potential conflict) |
| **Maintenance** | Minimal | High (Consul gossip, Vault HA, Nomad scheduling) |

## Current Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Compose Stack                     │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │emercoin-core │  │ yggdrasil    │  │  skywire     │       │
│  │  (Bitcoin    │  │  (mesh       │  │  (visor)     │       │
│  │   AuxPoW)    │  │  overlay)    │  │              │       │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘       │
│         │                  │                  │              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ privateness  │  │dns-reverse-  │  │pyuheprng-    │       │
│  │  (NESS)      │  │  proxy       │  │privatenesstls│       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
│                                                              │
│  ┌──────────────┐                                            │
│  │i2p-yggdrasil │  Requires: NET_ADMIN, SYS_MODULE, /dev/tun │
│  └──────────────┘                                            │
└─────────────────────────────────────────────────────────────┘
```

### Services Requiring Special Privileges

| Service | Capability | Reason |
|---------|-----------|--------|
| `yggdrasil` | `NET_ADMIN` | Create TUN interface for mesh networking |
| `i2p-yggdrasil` | `NET_ADMIN`, `SYS_MODULE` | TUN device + kernel module loading |
| `i2p-yggdrasil` | `/dev/net/tun` | Direct TUN device access |
| `i2p-yggdrasil` | `net.ipv6.conf.all.forwarding=1` | IPv6 forwarding for overlay |

## HashiCorp Stack Overview

### Nomad (Orchestration)
- **Pros**: Native Docker support, job scheduling, rolling updates
- **Cons**: Adds 300MB+ memory overhead, requires server agents

### Consul (Service Discovery)
- **Pros**: Service mesh, health checks, KV store for EmerNVS
- **Cons**: Gossip protocol overhead, RAFT consensus for HA

### Vault (Secrets)
- **Pros**: Dynamic credentials, encryption as a service
- **Cons**: Unseal ceremony, HA complexity, significant resource usage

## Migration Challenges

### 1. Network Privileges in Nomad

Nomad's Docker driver runs in **bridge mode by default**, with limited privileged options:

```hcl
# Nomad job snippet for yggdrasil
job "yggdrasil" {
  group "networking" {
    task "yggdrasil" {
      driver = "docker"
      
      config {
        image = "nessnetwork/yggdrasil"
        
        # Limited compared to Docker Compose
        privileged = true  # Required for NET_ADMIN
        
        devices = [
          {
            host_path = "/dev/net/tun"
            container_path = "/dev/net/tun"
          }
        ]
        
        # sysctls not directly supported in Nomad Docker driver
        # Would need host-level sysctl settings
      }
    }
  }
}
```

**Issue**: Nomad doesn't support per-container sysctls like Docker Compose. `net.ipv6.conf.all.forwarding=1` would need host-level configuration, reducing isolation.

### 2. Service Dependencies

Current Docker Compose dependencies:
```yaml
depends_on:
  emercoin-core:
    condition: service_healthy  # Wait for healthcheck
```

Nomad's `lifecycle` and `depends_on` are less granular - no native health condition support.

### 3. Volume Management

| Feature | Docker Compose | Nomad |
|---------|---------------|-------|
| Named volumes | Native | Requires CSI drivers |
| Host bind mounts | Simple | Simple |
| Volume persistence | Automatic | Requires host volumes or CSI |

Emercoin and Privateness blockchains require persistent storage. Nomad would need host volume constraints:

```hcl
job "emercoin" {
  constraint {
    attribute = "${attr.unique.hostname}"
    value     = "ness-node-1"  # Forces specific node
  }
  
  group "blockchain" {
    volume "emercoin-data" {
      type      = "host"
      source    = "emercoin-data"
      read_only = false
    }
  }
}
```

This reduces the "portable job" benefit of Nomad.

### 4. Decentralization Paradox

**Core Issue**: NESS Hub is about decentralized identity (EmerDNS) and privacy networks (Yggdrasil, I2P, Skywire).

Using HashiCorp Stack introduces **centralized orchestration**:
- Nomad servers become a single point of failure
- Consul requires coordination between nodes
- Vault requires unseal keys management

**Conflict with project ethos**:
```
NESS Vision:     Decentralized, self-sovereign, peer-to-peer
HashiCorp Stack: Centralized control plane, consensus-based
```

## Recommended Approach: Hybrid

### Keep Docker Compose for Core Services

Rationale:
1. **Simplicity**: Single-node deployment (Pi 3, Skyminer)
2. **Network requirements**: Full NET_ADMIN, tun devices, sysctls
3. **Portability**: Works on any Linux with Docker
4. **Alignment**: Matches decentralization philosophy

### Add Consul for Service Discovery (Optional)

If service discovery is needed across multiple NESS nodes:

```yaml
# docker-compose.consul.yml
services:
  consul:
    image: hashicorp/consul:1.17
    container_name: consul
    ports:
      - "8300:8300"   # Server RPC
      - "8301:8301"   # Serf LAN
      - "8500:8500"   # HTTP API
      - "8600:8600/udp"  # DNS
    command: >
      consul agent -server -bootstrap-expect=1 
      -ui -bind=0.0.0.0 -client=0.0.0.0
      -retry-join=localhost
    volumes:
      - consul-data:/consul/data
```

Use for:
- EmerDNS health checking
- Cross-node service discovery
- KV store for configuration

### Use Vault for Secrets (Optional)

Only if managing many wallet keys:

```yaml
# docker-compose.vault.yml
services:
  vault:
    image: hashicorp/vault:1.15
    container_name: vault
    ports:
      - "8200:8200"
    environment:
      - VAULT_DEV_ROOT_TOKEN_ID=dev-token
      - VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200
```

**Note**: Vault dev mode is not for production. Production requires HA backend (Consul, etcd, S3).

## Decision Matrix

| If You Need... | Use | Don't Use |
|----------------|-----|-----------|
| Single Pi 3 / Skyminer | Docker Compose | Nomad (overkill) |
| 5+ nodes with shared jobs | Nomad + Docker Compose | Pure Docker Swarm |
| Service mesh between nodes | Consul | Built-in DNS |
| Wallet key management | Vault (carefully) | Env vars (current) |
| Zero-downtime updates | Nomad | Compose (manual) |
| Decentralized philosophy | Docker Compose | HashiCorp Stack |

## Conclusion

### For NESS Hub's Use Case: **Stick with Docker Compose**

The project targets:
- Raspberry Pi 3 (limited resources)
- Skyminer hardware (single-node deployment)
- Privacy-conscious users (avoid central orchestration)
- Decentralized identity (conflict with central control planes)

**HashiCorp Stack adds ~1GB RAM overhead** for Nomad+Consul+Vault servers, which is significant for Pi 3 (1GB RAM).

### If Expanding to Cluster Mode

Only consider Nomad if:
1. Running 10+ NESS nodes
2. Need automatic failover between nodes
3. Have dedicated orchestration hardware (not running on Pi)
4. Willing to accept centralization trade-off

### Suggested Enhancement (Not Replacement)

Enhance the current `ness-tui.sh` with:
1. Multi-node awareness via simple SSH-based coordination
2. Built-in health checks (already present)
3. Optional Consul agent for cross-node discovery
4. GPG-based secret management (fits decentralization ethos)

```
Recommended Path:
ness-tui.sh (Docker Compose) + Optional Consul for clustering
                    ↓
         NOT HashiCorp Stack (too heavy, too centralized)
```
