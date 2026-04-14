#!/bin/sh
set -e

# --- Inject RPC credentials into emcssh.conf at runtime ---
EMC_RPC_USER="${EMC_RPC_USER:-emercoin}"
EMC_RPC_PASS="${EMC_RPC_PASS:-}"

if [ -z "$EMC_RPC_PASS" ]; then
    echo "[ssh-gateway] WARNING: EMC_RPC_PASS not set — emcssh will use fallback NVS sources only"
fi

sed -i \
    -e "s|EMCRPCUSER|${EMC_RPC_USER}|g" \
    -e "s|EMCRPCPASS|${EMC_RPC_PASS}|g" \
    /etc/emercoin/emcssh.conf

# --- Generate host key: Ed25519 only ---
# RSA/DSA/ECDSA intentionally not generated — see sshd_config HostKeyAlgorithms
[ -f /etc/ssh/ssh_host_ed25519_key ] || ssh-keygen -q -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""
rm -f /etc/ssh/ssh_host_rsa_key /etc/ssh/ssh_host_dsa_key /etc/ssh/ssh_host_ecdsa_key 2>/dev/null || true

# --- Print host fingerprint for first-connect trust ---
echo "[ssh-gateway] Host key fingerprint:"
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key

# --- Wire in any authorized_keys from environment (fallback for bootstrapping) ---
if [ -n "$SSH_ADMIN_PUBKEY" ]; then
    echo "$SSH_ADMIN_PUBKEY" >> /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    echo "[ssh-gateway] Installed SSH_ADMIN_PUBKEY for root"
fi

# --- Run sshd in foreground ---
exec /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config
