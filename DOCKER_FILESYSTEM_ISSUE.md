# Docker Overlayfs Filesystem Issue

## Problem
Docker operations are failing with overlayfs whiteout file permission errors:
```
failed to convert whiteout file "var/lib/apt/lists/.wh.archive.ubuntu.com_ubuntu_dists_xenial-updates_InRelease": operation not permitted
```

This affects:
- Building Docker images locally
- Pulling Docker images from registry
- Extracting image layers

## Root Cause
The system is using `overlayfs` storage driver on a filesystem that doesn't properly support nested overlay mounts or has permission restrictions. This is common on:
- Certain VM configurations
- WSL2 environments
- Systems with AppArmor/SELinux restrictions
- Filesystems mounted with specific options

## Current Configuration
- Storage Driver: `overlayfs`
- User: `kali`
- System: Kaisen Linux

## Resolution Options

### Option 1: Switch Docker Storage Driver to VFS (Quick Fix)
**Warning**: VFS is slower and uses more disk space, but works on all filesystems.

```bash
# Stop Docker
sudo systemctl stop docker

# Backup current Docker data
sudo cp -r /var/lib/docker /var/lib/docker.backup

# Create/edit Docker daemon config
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<EOF
{
  "storage-driver": "vfs"
}
EOF

# Remove old Docker data (optional, but recommended for clean start)
sudo rm -rf /var/lib/docker/*

# Start Docker
sudo systemctl start docker

# Verify new storage driver
docker info | grep "Storage Driver"
```

### Option 2: Switch to fuse-overlayfs (Better Performance)
```bash
# Install fuse-overlayfs
sudo apt-get update
sudo apt-get install -y fuse-overlayfs

# Configure Docker to use fuse-overlayfs
sudo tee /etc/docker/daemon.json <<EOF
{
  "storage-driver": "fuse-overlayfs"
}
EOF

# Restart Docker
sudo systemctl restart docker
```

### Option 3: Fix Overlayfs Permissions (If on VM/Container)
```bash
# Check if running in a container/VM
systemd-detect-virt

# If in a container, you may need to run Docker in privileged mode
# or adjust the host's AppArmor/SELinux policies
```

### Option 4: Use Docker Rootless Mode
```bash
# Install rootless Docker
curl -fsSL https://get.docker.com/rootless | sh

# Follow the instructions to set up PATH and start dockerd-rootless
```

## After Fixing Storage Driver

Once the storage driver issue is resolved, run:

```bash
cd /mnt/KaisenLinux/@/home/rooty/ness.cx/hub.docker.com

# Clean start
docker compose down -v

# Pull images
docker compose pull

# Start services
docker compose up -d

# Check status
docker compose ps
docker compose logs -f
```

## Alternative: Use Simplified Stack

If you need to get running quickly without fixing the Docker storage issue, you can use `docker-compose.ness.yml` which has fewer services:

```bash
docker compose -f docker-compose.ness.yml up -d
```

## HTCondor Services

Note: HTCondor services are currently commented out in `docker-compose.yml` because:
1. Images don't exist in the nessnetwork registry
2. Local builds are blocked by the overlayfs issue

To enable them later:
1. Fix the Docker storage driver issue
2. Build the images locally: `bash build-all.sh`
3. Uncomment the HTCondor services in `docker-compose.yml`

## Status

✅ Configuration files updated (AmneziaWG removed, cookie auth implemented)
✅ Docker Compose configuration validated
❌ **BLOCKED**: Cannot start containers due to overlayfs filesystem issue

**Next Step**: Choose and implement one of the resolution options above.
