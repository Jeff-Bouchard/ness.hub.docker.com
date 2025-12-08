#!/bin/bash

set -euo pipefail

# Adjust if your repo path is different inside WSL
REPO_DIR="/mnt/h/ness.cx/hub.docker.com"

DOCKER_USER="${DOCKER_USER:-nessnetwork}"
COMPOSE_FILE="docker-compose.ness.yml"
SERVICE_NAME="emercoin-core"

echo "[*] Changing to repo: ${REPO_DIR}"
cd "${REPO_DIR}"

echo "[*] Building ${DOCKER_USER}/${SERVICE_NAME}:latest ..."
docker build -t "${DOCKER_USER}/${SERVICE_NAME}:latest" "./${SERVICE_NAME}"

echo "[*] Bringing up ${SERVICE_NAME} via ${COMPOSE_FILE} ..."
docker-compose -f "${COMPOSE_FILE}" up -d "${SERVICE_NAME}"

echo "[*] Waiting for ${SERVICE_NAME} healthcheck..."
for i in {1..10}; do
  status="$(docker inspect --format='{{.State.Health.Status}}' ${SERVICE_NAME} 2>/dev/null || echo "unknown")"
  echo "  - attempt ${i}: health=${status}"
  if [[ "${status}" == "healthy" ]]; then
    echo "[✓] ${SERVICE_NAME} is healthy."
    exit 0
  fi
  sleep 10
done

echo "[!] ${SERVICE_NAME} did not become healthy in time. Recent logs:"
docker logs --tail=200 "${SERVICE_NAME}" || true
exit 1
