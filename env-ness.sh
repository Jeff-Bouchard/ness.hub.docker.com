#!/usr/bin/env bash

# Source this file to add Ness CLI wrappers (emercoin-cli, privateness-cli, skywire-cli, ...) to your PATH.
# Usage:
#   cd /h/ness.cx/hub.docker.com
#   source ./env-ness.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case ":$PATH:" in
  *":$SCRIPT_DIR:"*) : ;; # already in PATH
  *) export PATH="$SCRIPT_DIR:$PATH" ;;
esac
