#!/usr/bin/env bash
set -euo pipefail

echo '=== CH12 VPN FINAL CHECK - fw01 ==='

echo '[1] WAN'
ip -4 -br addr show eth0
ip route show default
ping -c 1 10.250.0.1

echo '[2] WireGuard'
systemctl is-enabled wg-quick@wg0
systemctl is-active wg-quick@wg0
ip -br addr show wg0
ip route show 10.99.10.0/24
sudo wg show
sudo ss -lun | grep ':51820\b'

echo '[3] OpenVPN'
systemctl is-enabled openvpn-server@ch12
systemctl is-active openvpn-server@ch12
ip -br addr show tun0
ip route show 10.99.20.0/24
sudo ss -lun | grep ':1194\b'
sudo journalctl -u openvpn-server@ch12 -n 20 --no-pager |
    grep -E 'Initialization Sequence Completed|VERIFY|Peer Connection|Data Channel' || true

echo '[4] nftables forward counters'
sudo nft list chain inet filter forward | grep -E 'wg0|tun0' || true

echo 'Expected: eth0=10.250.0.2/24; wg0=10.99.10.1/24; tun0=10.99.20.1/24'
echo 'Checkpoint: CH12-VPN-FINAL-VALIDATED'