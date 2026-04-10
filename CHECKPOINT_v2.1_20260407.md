# NESS Hub Menu v2.1 Checkpoint
**Date:** 2026-04-07  
**Version:** v2.1

## Summary
Major update with service tiers, mobile-first HTML UI, individual container controls, and clear reseed configuration.

## Changes Made

### 1. Menu Script (`menu`) v2.1
- **Service Tiers Implemented:**
  - Tier 1 (Always): emercoin-core, privateness, skywire, pyuheprng-privatenesstools
  - Tier 2: yggdrasil, i2p-yggdrasil
  - Tier 3: dns-reverse-proxy
- **Reseeding:** Disabled by default, clear option [11] with seconds input (10-300)
- **Individual Controls:** Option [12] for per-container start/stop/restart/logs/cleanup
- **Persistent Volumes:** emercoin-data, skywire-data auto-created
- **Version Header:** Shows v2.1 and checkpoint date

### 2. Mobile-First HTML Dashboard (`ness-mobile.html`)
- **Touch-Optimized:** Large buttons, swipe-friendly, sticky header
- **Service Cards:** Tier-colored borders, status badges
- **Quick Actions:** Start All, Stop All, Restart, Health Check
- **Reseed Toggle:** Visual on/off with configuration
- **Individual Service Controls:** Each container has Start/Stop/Restart/Logs buttons
- **Responsive:** Works on phones, tablets, desktops

### 3. Container Updates
- **pyuheprng-privatenesstools:**
  - supervisord.conf: Both pyuheprng + privatenesstools enabled
  - Added pyuheprng-reseeder program (disabled by default)
  - entrypoint.sh: RESEED_INTERVAL env var support

### 4. Files Modified
- `menu` - Complete rewrite with tiers and individual controls
- `ness-mobile.html` - New mobile dashboard
- `pyuheprng-privatenesstools/supervisord.conf` - Added reseeder service
- `pyuheprng-privatenesstools/entrypoint.sh` - RESEED_INTERVAL support

## Usage

### Terminal Menu
```bash
./menu
# [1] Start All - Tier 1 first, then Tier 2/3 if full profile
# [11] Set Reseed - Enter seconds (10-300) or disable
# [12] Per-Container - Individual start/stop/restart/logs/cleanup
```

### Mobile Dashboard
```bash
# Open in browser
firefox ness-mobile.html
# or on phone via local server
python3 -m http.server 8080
# Then visit http://your-ip:8080/ness-mobile.html
```

## Architecture
```
Tier 1 (Always Running):
  - emercoin-core (blockchain data persistent)
  - privateness (privacy layer)
  - skywire (mesh network)
  - pyuheprng-privatenesstools (entropy + utilities)

Tier 2 (Optional - Full Profile):
  - yggdrasil (network mesh)
  - i2p-yggdrasil (anonymity)

Tier 3 (Optional - Full Profile):
  - dns-reverse-proxy (DNS services)
```

## Testing Checklist
- [ ] Menu starts Tier 1 services first
- [ ] Reseed disabled by default, enables with custom seconds
- [ ] Per-container controls work (start/stop/restart/logs)
- [ ] Mobile dashboard renders correctly on phone
- [ ] Touch buttons are large enough (44px min)
- [ ] Emercoin blockchain persists across restarts

## Notes
- Podman preferred over Docker for Pi3 (lighter resource usage)
- No Portainer needed (direct podman-compose control)
- All containers have same controls: start, stop, restart, cleanup, logs
