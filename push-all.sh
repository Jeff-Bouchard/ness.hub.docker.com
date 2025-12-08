#!/bin/bash

set -e

DOCKER_USER="nessnetwork"

echo "Pushing all images to Docker Hub (${DOCKER_USER})..."

# Push each image
docker push ${DOCKER_USER}/emercoin-core
docker push ${DOCKER_USER}/ness-blockchain
docker push ${DOCKER_USER}/privateness
docker push ${DOCKER_USER}/skywire
docker push ${DOCKER_USER}/pyuheprng
docker push ${DOCKER_USER}/privatenumer
docker push ${DOCKER_USER}/privatenesstools
docker push ${DOCKER_USER}/pyuheprng-privatenesstools
docker push ${DOCKER_USER}/yggdrasil
docker push ${DOCKER_USER}/i2p-yggdrasil
docker push ${DOCKER_USER}/dns-reverse-proxy
docker push ${DOCKER_USER}/ipfs
docker push ${DOCKER_USER}/amneziawg
docker push ${DOCKER_USER}/skywire-amneziawg
docker push ${DOCKER_USER}/amnezia-exit
docker push ${DOCKER_USER}/ness-unified

echo "All images pushed successfully to ${DOCKER_USER}!"
