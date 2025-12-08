#!/bin/bash

set -e

echo "=========================================="
echo "Deploying Ness Essential Stack"
echo "=========================================="
echo "Services:"
echo "  - Emercoin Core (blockchain)"
echo "  - pyuheprng + privatenesstools (entropy + tools)"
echo "  - DNS Reverse Proxy (decentralized DNS)"
echo "  - Privateness (core application)"
echo "=========================================="

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "ERROR: Docker is not running"
    exit 1
fi

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "ERROR: docker-compose is not installed"
    exit 1
fi

# Check for GRUB/cmdline configuration
echo "Checking entropy configuration..."
if grep -q "random.trust_cpu=off" /proc/cmdline 2>/dev/null; then
    echo "✓ Entropy protections enabled"
else
    echo "⚠ WARNING: Entropy protections not configured"
    echo ""
    echo "For production, configure GRUB/cmdline:"
    echo ""
    if [ -f /boot/cmdline.txt ]; then
        echo "  # Raspberry Pi - edit /boot/cmdline.txt"
        echo "  sudo nano /boot/cmdline.txt"
        echo "  # Add: random.trust_cpu=off random.trust_bootloader=off"
    else
        echo "  # Standard Linux - edit /etc/default/grub"
        echo "  sudo nano /etc/default/grub"
        echo "  # Add: GRUB_CMDLINE_LINUX=\"random.trust_cpu=off random.trust_bootloader=off\""
        echo "  sudo update-grub"
    fi
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Deploy the stack
echo ""
echo "Deploying Ness stack..."
docker-compose -f docker-compose.ness.yml up -d

echo ""
echo "=========================================="
echo "Deployment complete!"
echo "=========================================="
echo ""
echo "Services running:"
docker-compose -f docker-compose.ness.yml ps
echo ""
echo "Health checks:"
echo "  Emercoin Core:  http://localhost:6662"
echo "  pyuheprng:      http://localhost:5000/health"
echo "  privatenesstools: http://localhost:8888/health"
echo "  DNS Proxy:      http://localhost:8053"
echo "  Privateness:    http://localhost:8080"
echo ""
echo "Check entropy:"
echo "  cat /proc/sys/kernel/random/entropy_avail"
echo ""
echo "View logs:"
echo "  docker-compose -f docker-compose.ness.yml logs -f"
echo "=========================================="
