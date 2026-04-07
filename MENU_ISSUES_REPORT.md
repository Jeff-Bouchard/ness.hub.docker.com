- disa# NESS Docker Hub Menu Issues Report

## Summary

This report documents critical issues found in the NESS Docker Hub menu scripts and provides a working fixed TUI menu (`ness-tui.sh`).

---

## Critical Issue #1: Infinite Recursion Bug (CRITICAL)

### Location
- **File**: `ness-menu-v4.sh`, `ness-menu-v3.sh`, `menu-v3.sh`
- **Lines**: 183-189

### The Bug
```bash
docker() {
  "$CONTAINER_ENGINE" "$@"
}

compose() {
  docker compose -f "$COMPOSE_FILE" "$@"  # BUG: Calls docker() function, not docker binary!
}
```

### Root Cause
The `docker()` function wrapper creates infinite recursion:
1. `compose()` calls `docker compose ...`
2. Bash resolves `docker` to the function `docker()`, not the system binary
3. `docker()` calls `"$CONTAINER_ENGINE"` which is set to `"docker"`
4. This again resolves to the `docker()` function
5. Infinite loop until stack overflow/segfault

### Screenshot of Issue
When running the broken menu, the `compose ps` command spams repeatedly:
```
+ compose ps
+ docker compose -f docker-compose.yml ps
+ docker compose -f docker-compose.yml ps
+ docker compose -f docker-compose.yml ps
... (repeats hundreds of times)
```

### Fix
Replace the `docker()` wrapper with a properly namespaced function:
```bash
# WRONG (causes infinite recursion)
docker() {
  "$CONTAINER_ENGINE" "$@"
}
compose() {
  docker compose -f "$COMPOSE_FILE" "$@"
}

# CORRECT
run_docker() {
    command $CONTAINER_ENGINE "$@"
}
run_compose() {
    run_docker compose -f "$COMPOSE_FILE" "$@"
}
```
The `command` builtin bypasses function lookup, calling the actual binary.

---

## Issue #2: Broken Menu Layout

### Location
- `ness-menu-v4.sh` lines 924-943

### Problem
The menu display has formatting issues with box-drawing characters not aligning properly in some terminals.

### Screenshot
```
${panel_bg}${panel_border}╔══════════════════╦═══════════════════════════════╗${reset}
║ Menu V3          ║ Reality: hybrid → Hybrid (EmerDNS first, ICANN fallback)
╠══════════════════╩═══════════════════════════════╣
```

---

## Issue #3: Missing Container Engine Support

### Location
- All menu scripts

### Problem
The `require_docker()` function only checks for `docker`, not alternative engines like `podman`.

### Environment Context
This system uses podman with docker-compose:
```
Emulate Docker CLI using podman. 
>>>> Executing external compose provider "/usr/bin/docker-compose".
```

---

## Issue #4: Hardcoded Script Paths

### Location
- `ness-menu-v4.1.py` line 15

### Problem
```python
MENU_SCRIPT = os.path.join(SCRIPT_DIR, "ness-menu-v4.sh")
```
The Python bridge hardcodes the shell script path, making it brittle if the script is renamed.

---

## Issue #5: Missing DNS Label Customization in API Mode

### Location
- `ness-menu-v4.sh` api_dispatch function (line 1292+)

### Problem
The API dispatch mode doesn't support setting custom DNS labels via the API, only interactive mode.

---

## Image Files Review

The following image assets are present in the repository:

### Documentation Images
| Image | Status | Notes |
|-------|--------|-------|
| `ness200x200.jpg` | ✓ OK | Main logo, 22005 bytes |
| `How-DNS-fits-into-the-OSI-model.jpg` | ✓ OK | Architecture diagram, 141KB |
| `OSI-Reference-Model-1024x486.webp` | ✓ OK | OSI model reference |
| `osi-network-model-28867034.webp` | ✓ OK | Network model diagram |
| `osi-model-responsabilities-machine-network.png` | ✓ OK | OSI responsibilities diagram |

### Other Assets
| Image | Status | Notes |
|-------|--------|-------|
| `existence-denied.gif` | ✓ OK | 4.8MB animated GIF |
| `qr-benji.png` | ✓ OK | QR code asset |
| `nfh-ness-midnight_*.jpg` | ✓ OK | Background image |

### Doc Folder Images
| Image | Status | Notes |
|-------|--------|-------|
| `doc/1minute-identitybedrock.png` | ✓ OK | Documentation figure |
| `doc/1minute-identitybedrock-fr.png` | ✓ OK | French version |
| `doc/unbreakablehuman.png` | ✓ OK | Documentation figure |

---

## Working Fixed TUI Menu

A new fixed menu has been created: **`ness-tui.sh`**

### Key Fixes
1. **Fixed infinite recursion** using `command` builtin
2. **Simplified menu structure** - cleaner, working UI
3. **Podman compatibility** - respects CONTAINER_ENGINE
4. **Clean exit handling** - no segfaults

### Usage
```bash
./ness-tui.sh
```

### Menu Options
- `[1]` Start Stack - Starts containers based on selected profile
- `[2]` Stop Stack - Stops all containers
- `[3]` Stack Status - Shows container statuses
- `[4]` Tail Logs - Follow container logs
- `[5]` Test Services - Tests TCP ports
- `[6]` Select Profile - Choose Pi3/Skyminer/Full
- `[7]` Build Images - Reference to build-all.sh
- `[0]` Exit

---

## Recommendations

### Immediate Actions
1. **Replace** `docker()` wrapper functions with namespaced alternatives using `command`
2. **Test** all menu scripts with both Docker and Podman environments
3. **Update** `ness-menu-v4.1.py` to use dynamic script discovery

### Code Quality Improvements
1. Add shellcheck validation to CI/CD
2. Add integration tests for menu scripts
3. Document the CONTAINER_ENGINE environment variable
4. Add timeout safeguards for docker compose calls

### Architecture Improvements
1. Consolidate multiple menu versions into one maintainable script
2. Remove unused HTML-based menus if not actively maintained
3. Add proper error handling for missing docker-compose.yml

---

## Tested Commands

### Fixed Menu Test
```bash
$ echo "3" | timeout 3 ./ness-tui.sh
    /\        _                
   /  \  __ _| |_ _ __ _   _   
  / /\ \/ _' | __| '__| | | |  
 / ____ \ (_| | |_| |  | |_| | 
\_/   \ \__/|\__|_|   \__/|  
# Shows status without crashing ✓
```

### Broken Menu Test
```bash
$ timeout 3 bash ness-menu-v4.sh api --action stack-status
# Segfault due to infinite recursion ✗
```

---

## Conclusion

The primary issue preventing the TUI menus from working is the **infinite recursion bug** in the `docker()` wrapper function. The fixed `ness-tui.sh` script resolves this and provides a functional, simplified menu interface.

## Files Created/Modified

| File | Action | Description |
|------|--------|-------------|
| `ness-tui.sh` | ✨ NEW | Fixed working TUI menu |
| `ness-menu-v4.sh` | ⚠️ BUGGY | Has infinite recursion |
| `ness-menu-v3.sh` | ⚠️ BUGGY | Has infinite recursion |
| `menu-v3.sh` | ⚠️ BUGGY | Has infinite recursion |

---

*Report generated: April 7, 2026*
