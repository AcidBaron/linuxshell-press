#!/usr/bin/env bash
# Helper di repository ricavato dai controlli finali del Capitolo 12.
# I singoli comandi sono stati eseguiti nel laboratorio; questo file li
# raccoglie per rendere ripetibile la verifica.

set -euo pipefail

echo "=== WAN ==="
ip -4 -br addr show eth0
ip route show default

echo "=== WIREGUARD ==="
systemctl is-enabled wg-quick@wg0
systemctl is-active wg-quick@wg0
ip -br addr show wg0
ip route show 10.99.10.0/24
sudo wg show

echo "=== OPENVPN ==="
systemctl is-enabled openvpn-server@ch12
systemctl is-active openvpn-server@ch12
ip -br addr show tun0
ip route show 10.99.20.0/24

echo "=== LISTENER ==="
sudo ss -lun | grep -E ':51820\b|:1194\b'

echo "=== NFTABLES ==="
sudo nft -c -f /etc/nftables.conf
sudo nft list chain inet filter forward | grep -E 'wg0|tun0'
