#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_USER="${DOCKER_USER:-nessnetwork}"
BUILDER_NAME="${BUILDER_NAME:-ness-builder}"

# Tier definitions
TIER1_PLATFORMS="linux/amd64,linux/arm64,linux/arm/v7"
TIER1_IMAGES=(
  "emercoin-core"
  "skywire"
  "dns-reverse-proxy"
  "privateness"
  "pyuheprng"
  "privatenesstools"
)

TIER2_PLATFORMS="linux/amd64,linux/arm64"
TIER2_IMAGES=(
  "amneziawg"
  "skywire-amneziawg"
  "amnezia-exit"
  "yggdrasil"
  "ipfs"
  "i2p-yggdrasil"
  "ness-unified"
)

TIER3_PLATFORMS="linux/amd64,linux/arm64"
TIER3_IMAGES=(
  "privatenumer"
)

TIER4_PLATFORMS="linux/amd64,linux/arm64"
TIER4_IMAGES=(
  "emercoin-mcp-server"
  "privateness-mcp-server"
  "emercoin-mcp-app"
  "privateness-mcp-app"
  "magic-wormhole-suite"
  "inspector"
)

ensure_builder() {
  if ! docker buildx inspect "$BUILDER_NAME" >/dev/null 2>&1; then
    echo "Creating buildx builder '$BUILDER_NAME'..."
    docker buildx create --name "$BUILDER_NAME" --driver docker-container --use >/dev/null
  else
    docker buildx use "$BUILDER_NAME" >/dev/null
  fi
}

build_group() {
  local platforms="$1"
  shift
  local images=("$@")

  for image in "${images[@]}"; do
    local context_path="${SCRIPT_DIR}/${image}"
    if [[ ! -d "$context_path" ]]; then
      echo "[ERROR] Missing build context for '$image' at $context_path" >&2
      exit 1
    fi

    echo "\n>>> Building ${DOCKER_USER}/${image}:latest for ${platforms}"
    docker buildx build \
      --builder "$BUILDER_NAME" \
      --progress=plain \
      --platform "$platforms" \
      -t "${DOCKER_USER}/${image}:latest" \
      --push \
      "$context_path"
  done
}

ensure_builder

echo "Building Tier 1 (Pi3-safe) images..."
build_group "$TIER1_PLATFORMS" "${TIER1_IMAGES[@]}"

echo "Building Tier 2 (heavy / 64-bit) images..."
build_group "$TIER2_PLATFORMS" "${TIER2_IMAGES[@]}"

echo "Building Tier 3 (VOIP / WebRTC) images..."
build_group "$TIER3_PLATFORMS" "${TIER3_IMAGES[@]}"

echo "Building Tier 4 (MCP servers/apps + inspector) images..."
build_group "$TIER4_PLATFORMS" "${TIER4_IMAGES[@]}"

echo "\nAll multi-architecture images built and pushed successfully!"
