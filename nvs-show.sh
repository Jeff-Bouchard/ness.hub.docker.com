#!/usr/bin/env bash
# Helper to show common EmerNVS records with required filtering
# Usage:
#   ./nvs-show.sh [key]
# If no key is provided, it shows: ness:wallet, ness:hub, ness:id

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMERCOIN_CLI="${EMERCOIN_CLI:-emercoin-cli}"

need_tools() {
  if ! command -v "$EMERCOIN_CLI" >/dev/null 2>&1; then
    echo "[ERROR] Emercoin CLI not found. Set EMERCOIN_CLI or install emercoin-cli." >&2
    exit 1
  fi
  if ! command -v python >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
    echo "[ERROR] Python is required for emercoin-value.py/emercoin-format.py filters." >&2
    exit 1
  fi
}

py() {
  command -v python >/dev/null 2>&1 && echo python || echo python3
}

show_key() {
  local key="$1"
  # Always filter JSON via emercoin-value.py
  local val
  val=$($EMERCOIN_CLI name_show "$key" | $(py) "$SCRIPT_DIR/emercoin-value.py")
  if [ "$key" = "ness:id" ]; then
    # For ness:id, interpret escaped newlines to render full HTML nicely
    echo "$val" | $(py) "$SCRIPT_DIR/emercoin-format.py"
  else
    echo "$val"
  fi
}

main() {
  need_tools
  if [ $# -gt 0 ]; then
    show_key "$1"
    exit 0
  fi
  echo "-- ness:wallet --"
  show_key ness:wallet || true
  echo
  echo "-- ness:hub --"
  show_key ness:hub || true
  echo
  echo "-- ness:id (HTML) --"
  show_key ness:id || true
}

main "$@"
