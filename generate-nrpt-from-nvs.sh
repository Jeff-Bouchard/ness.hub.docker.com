#!/usr/bin/env bash

# Generate a Windows NRPT .reg file from the on-chain Emercoin NVS record
#   ness:dns-reverse-proxy-config
#
# This script:
#   - Uses emercoin-cli to fetch the NVS value
#   - Parses dns-reverse-proxy arguments, extracting all -route suffixes
#   - Emits a .reg file on stdout with a single NRPT policy whose Name list
#     matches the on-chain suffix list and whose GenericDNSServers points
#     at your resolver (ns74.com by default)
#
# Usage (on a host with emercoin-cli):
#   EMERCOIN_CLI=emercoin-cli DNS_SERVER=ns74.com \
#     ./generate-nrpt-from-nvs.sh > EmerDNESS.reg
#
# Then import EmerDNESS.reg on Windows (regedit /s EmerDNESS.reg).

set -euo pipefail

EMERCOIN_CLI="${EMERCOIN_CLI:-emercoin-cli}"
DNS_NVS_KEY="${DNS_NVS_KEY:-ness:dns-reverse-proxy-config}"
DNS_SERVER="${DNS_SERVER:-ns74.com}"
POLICY_GUID="${POLICY_GUID:-{4bb812c0-e47a-48a8-aafc-f9c821cb1179}}"

# Fetch NVS record value from Emercoin (filtered via Python helper)
if [ -x "./emercoin-value.py" ]; then
  VALUE="$($EMERCOIN_CLI name_show "$DNS_NVS_KEY" | python ./emercoin-value.py)"
else
  # Fallback to sed if helper missing
  RESPONSE="$($EMERCOIN_CLI name_show "$DNS_NVS_KEY")"
  VALUE=$(printf '%s' "$RESPONSE" | sed -n 's/.*"value"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p') || true
fi

if [ -z "$VALUE" ]; then
  echo "ERROR: Could not extract 'value' from name_show response for $DNS_NVS_KEY" >&2
  exit 1
fi

# Unescape common JSON sequences (same approach as dns-reverse-proxy entrypoint)
VALUE=$(printf '%s' "$VALUE" | sed 's/\\n/\n/g; s/\\"/"/g')

# Parse -route arguments from the dns-reverse-proxy CLI string
routes_suffixes=()
prev=""
for token in $VALUE; do
  if [ "$prev" = "-route" ]; then
    route="$token"        # e.g. .ness.=ns74.com:53 or .ness.=8.8.8.8:53,1.1.1.1:53
    ns="${route%%=*}"      # take left side before '=': e.g. .ness.
    case "$ns" in
      .*)
        case "$ns" in
          *.) ns="${ns%.}" ;;  # drop trailing dot: .ness. -> .ness
        esac
        routes_suffixes+=("$ns")
        ;;
    esac
  fi
  prev="$token"
done

if [ "${#routes_suffixes[@]}" -eq 0 ]; then
  echo "ERROR: No -route entries found in NVS value for $DNS_NVS_KEY" >&2
  exit 1
fi

# Deduplicate suffixes while preserving order
unique_suffixes=()
for s in "${routes_suffixes[@]}"; do
  dup=0
  for u in "${unique_suffixes[@]}"; do
    if [ "$u" = "$s" ]; then
      dup=1
      break
    fi
  done
  if [ $dup -eq 0 ]; then
    unique_suffixes+=("$s")
  fi
done

# Encode REG_MULTI_SZ (hex(7)) for the Name value
encode_multisz() {
  # Arguments: list of strings
  local first=1
  local s i ch code len
  for s in "$@"; do
    len=${#s}
    for ((i=0; i<len; i++)); do
      ch=${s:i:1}
      # Use shell char constant syntax: printf '%d' "'A" => 65
      code=$(printf '%02x' "'${ch}")
      if [ $first -eq 1 ]; then
        printf "%s,00" "$code"
        first=0
      else
        printf ",%s,00" "$code"
      fi
    done
    # String terminator: 00,00
    printf ",00,00"
  done
}

# Emit .reg file
echo "Windows Registry Editor Version 5.00"
echo
echo "[HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\Dnscache\\Parameters\\DnsPolicyConfig\\$POLICY_GUID]"
echo "\"ConfigOptions\"=dword:00000008"
printf '"Name"=hex(7):'
encode_multisz "${unique_suffixes[@]}"
echo
echo "\"IPSECCARestriction\"=\"\""
echo "\"GenericDNSServers\"=\"$DNS_SERVER\""
echo "\"Version\"=dword:00000002"
