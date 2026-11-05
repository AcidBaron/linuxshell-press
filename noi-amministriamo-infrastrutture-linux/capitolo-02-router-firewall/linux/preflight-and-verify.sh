#!/usr/bin/env bash
set -u

echo "=== PREFLIGHT / RUNTIME ==="
ip -br addr
ip route
sysctl net.ipv4.ip_forward
command -v nft
sudo nft list ruleset
systemctl status nftables --no-pager || true
dpkg -l nftables | grep '^ii'
dpkg -l ufw | grep '^ii' || true
sudo ufw status verbose || true

echo
echo "=== PERSISTENCE ==="
systemctl is-enabled nftables
systemctl is-active nftables
sysctl net.ipv4.ip_forward
sudo nft list ruleset

echo
echo "=== TROUBLESHOOTING SNAPSHOT ==="
sudo journalctl -u nftables --no-pager
