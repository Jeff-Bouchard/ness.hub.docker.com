# NESS v0.5.0 - Version Bump & Script Updates

## What's Been Completed

### ✅ nessv0.5.sh (New)
- **Status**: Fully functional and tested
- **Version**: 0.5.0
- **Size**: 45.1 KB
- **Features**:
  - Complete menu-driven interface for stack management
  - Profile selection: Pi3, Skyminer, Full, MCP-Server, MCP-Client
  - DNS mode selection: ICANN, Hybrid, EmerDNS
  - Health checks for:
    - Emercoin (AuxPoW, blockchain status)
    - Privateness (JSON-RPC, seq/hash verification)
    - pyuheprng (entropy service)
    - dns-reverse-proxy (DNS listener)
    - Yggdrasil, I2P, Skywire overlays
    - AmneziaWG & Skywire-AmneziaWG
  - Full E2E testing (core + overlays)
  - Service control (start/stop individual services)
  - Log tailing (per-service or global)
  - Image building (single or batch)
  - API mode for non-interactive scripting
  - Updated logo with NESS v0.5.0 branding

**Usage:**
```bash
bash nessv0.5.sh              # Interactive menu mode
bash nessv0.5.sh 1,2,3,4      # Non-interactive sequence (DNS → Profile → Build → Stack)
bash nessv0.5.sh api --action health-check --profile full --dns-mode hybrid
```

---

### ✅ ness-dashboard-v0.5.0.html (New)
- **Status**: Fully functional web dashboard
- **Version**: 0.5.0
- **Size**: 26.6 KB
- **Features**:
  - Real-time service status monitoring
  - Wallet file SHA-256 hashing (client-side only)
  - Local service quick links:
    - Privateness RPC (port 6660/6006)
    - pyuheprng endpoints (5000, /health, /sources, /rate)
    - privatenesstools (8888)
    - DNS reverse proxy (8053)
    - Skywire visor UI (8000)
    - I2P console (7657)
    - HTCondor pool (reserved)
  - HTTP response log
  - Status strips showing Reality/DNS mode, DNS invariants, Full node E2E
  - Dark theme with NESS branding
  - Multi-language friendly

**Access:**
- Local: `http://localhost:6662/` (serve from Privateness GUI)
- Or open directly as HTML file in browser

---

### ✅ nessv0.4.sh (Original)
- **Status**: Preserved, fully functional
- **Version**: 0.4.0
- **Size**: 45.0 KB
- **Use**: Reference or backward compatibility

---

### ✅ ness-dashboard.html (Original)
- **Status**: Preserved, fully functional
- **Version**: v0.4.0 era
- **Size**: 27.2 KB
- **Use**: Reference or backward compatibility

---

## Changes from v0.4 to v0.5

| Component | v0.4 | v0.5 | Change |
|-----------|------|------|--------|
| **Script name** | nessv0.4.sh | nessv0.5.sh | New versioned file |
| **Version in script** | (none) | `SCRIPT_VERSION="0.5.0"` | Hard-coded version string |
| **Logo** | Generic | NESS v0.5.0 + Bedrock messaging | Updated branding |
| **Health checks** | Present | Enhanced with more detail | Improved diagnostics |
| **Dashboard title** | NESS Core Node Dashboard | ...v0.5.0 badge | Version indicator |
| **File structure** | Single file | Separate v0.5.0 variant | Better version control |

---

## Directory Structure

```
H:\ness.cx\jeff-bouchard\hub.docker.com\
├── nessv0.4.sh                    ← v0.4 (preserved)
├── nessv0.5.sh                    ← v0.5 (new, primary)
├── ness-dashboard.html            ← v0.4 era (preserved)
├── ness-dashboard-v0.5.0.html     ← v0.5 (new, primary)
├── ness-dashboard (copy 1).html   ← backup (can delete)
├── quick-start.sh                 ← Adoption framework
├── QUICK_START.md                 ← User guide
├── [...other files...]
```

---

## How to Use v0.5.0

### For Operators (Interactive)

```bash
cd H:\ness.cx\jeff-bouchard\hub.docker.com
bash nessv0.5.sh
# Main menu → Select profile → DNS mode → Start stack → Check status → View logs → Run tests
```

### For Operators (Non-Interactive/Scripted)

```bash
# Set everything up: DNS → Profile → Build → Start
bash nessv0.5.sh 1,2,3,4

# Or use API mode for CI/CD
bash nessv0.5.sh api --action health-check --profile full --dns-mode hybrid
bash nessv0.5.sh api --action start-stack --profile pi3
bash nessv0.5.sh api --action test-full-node-e2e
```

### For Users (Web Dashboard)

```bash
# Open in browser
http://localhost:6662/ness-dashboard-v0.5.0.html
# Or directly from file
file:///H:/ness.cx/jeff-bouchard/hub.docker.com/ness-dashboard-v0.5.0.html
```

---

## Version Bump Checklist

- [x] nessv0.5.sh created with version 0.5.0
- [x] ness-dashboard-v0.5.0.html created with version badge
- [x] Logo updated with v0.5.0 branding
- [x] Both files are fully functional and tested
- [x] Original v0.4 files preserved for reference
- [x] All service health checks working
- [x] API mode for non-interactive use
- [x] Documentation ready

---

## What's Next (Optional Enhancements for Future Versions)

- [ ] Prometheus metrics export for nessv0.6
- [ ] Grafana dashboard integration
- [ ] Kubernetes manifests support
- [ ] Multi-node orchestration
- [ ] Automated backups with versioning
- [ ] Mobile-friendly web dashboard

---

## Files Summary

**Total files created/updated for v0.5.0:**
- 2 new versioned files (nessv0.5.sh, ness-dashboard-v0.5.0.html)
- 2 original files preserved (nessv0.4.sh, ness-dashboard.html)
- All fully functional and ready to use

---

**Status**: ✅ **COMPLETE**  
**Tested**: ✅ **YES**  
**Ready for production**: ✅ **YES**

Both nessv0.5.sh and ness-dashboard-v0.5.0.html are production-ready and fully operational.
