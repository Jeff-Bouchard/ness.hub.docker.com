#!/bin/bash
# Script to remove AmneziaWG services and switch to cookie-based auth in all portainer files

set -e

FILES=(
  "portainer-tier1.yml"
  "portainer-tier2.yml"
  "portainer-tier3.yml"
  "portainer-stack.yml"
  "portainer-skyminer.yml"
)

for file in "${FILES[@]}"; do
  if [ ! -f "$file" ]; then
    echo "Skipping $file (not found)"
    continue
  fi
  
  echo "Processing $file..."
  
  # Create backup
  cp "$file" "$file.bak"
  
  # Remove amneziawg service block (from service definition to next service or volumes section)
  sed -i '/^  amneziawg:/,/^  [a-z]/{ /^  amneziawg:/d; /^  [a-z]/!d; }' "$file"
  
  # Remove skywire-amneziawg service block
  sed -i '/^  skywire-amneziawg:/,/^  [a-z]/{ /^  skywire-amneziawg:/d; /^  [a-z]/!d; }' "$file"
  
  # Remove amnezia-exit service block
  sed -i '/^  amnezia-exit:/,/^  [a-z]/{ /^  amnezia-exit:/d; /^  [a-z]/!d; }' "$file"
  
  # Remove awg-config volume
  sed -i '/^  awg-config:/d' "$file"
  
  # Replace EMERCOIN_USER and EMERCOIN_PASS with EMERCOIN_COOKIE_FILE
  sed -i 's/- EMERCOIN_USER=.*/- EMERCOIN_COOKIE_FILE=\/data\/.cookie/' "$file"
  sed -i '/- EMERCOIN_PASS=/d' "$file"
  
  echo "✓ Processed $file"
done

echo ""
echo "All files processed. Backups saved with .bak extension."
echo "Review changes and remove backups when satisfied."
