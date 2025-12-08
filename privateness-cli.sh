#!/usr/bin/env bash

# Simple wrapper to run privateness-cli inside the Docker container
# Usage:
#   ./privateness-cli status
#   ./privateness-cli help

MSYS_NO_PATHCONV=1 docker exec -it privateness privateness-cli "$@"
