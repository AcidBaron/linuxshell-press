#!/usr/bin/env bash
set -euo pipefail

echo "=== CH12 VPN FINAL CHECK - fw01 ==="

ip -4 -br addr show eth0
ip route show default

systemctl is-enabled wg-quick@wg0
systemctl is-enabled openvpn-server@ch12
systemctl is-active wg-quick@wg0
systemctl is-active openvpn-server@ch12

ip -br addr show wg0
ip -br addr show tun0

sudo ss -lun | grep -E ':51820\b|:1194\b'

sudo nft -c -f /etc/nftables.conf

sudo nft list chain inet filter input |
    grep -E '51820|1194|wg0|tun0|10\.99\.10|10\.99\.20' || true

sudo nft list chain inet filter forward |
    grep -E 'wg0|tun0|10\.99\.10|10\.99\.20'

sudo wg show

sudo journalctl \
    -u openvpn-server@ch12 \
    -n 30 \
    --no-pager
