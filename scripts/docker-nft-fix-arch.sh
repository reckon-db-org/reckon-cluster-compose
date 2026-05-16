#!/usr/bin/env bash
# Fix docker startup on Arch when iptables-nft fails with
# "Could not fetch rule set generation id: Invalid argument".
#
# Loads the netfilter kernel modules docker's bridge driver expects,
# clears the start-limit on the unit, and retries.
set -euo pipefail

echo "==> Load netfilter kernel modules"
for mod in nf_tables nft_chain_nat nft_compat nf_conntrack nf_nat iptable_nat iptable_filter; do
    if ! lsmod | grep -q "^${mod} "; then
        echo "  modprobe ${mod}"
        sudo modprobe "${mod}" 2>&1 | sed 's/^/    /' || echo "    (skip — kernel may not have it)"
    fi
done

echo
echo "==> Persist module loads on boot"
sudo tee /etc/modules-load.d/docker-netfilter.conf >/dev/null <<'EOF'
nf_tables
nft_chain_nat
nft_compat
nf_conntrack
nf_nat
iptable_nat
iptable_filter
EOF

echo
echo "==> Probe whether iptables works now"
sudo iptables -L -n -t nat 2>&1 | head -3 || echo "  (iptables still broken — needs reboot)"

echo
echo "==> Reset docker.service start-limit + try again"
sudo systemctl reset-failed docker.service
sudo systemctl start docker.service

echo
echo "==> docker.service status (last few lines)"
sudo systemctl status docker.service --no-pager -l 2>&1 | head -10

echo
echo "==> If still failed, a reboot is the most reliable cure."
