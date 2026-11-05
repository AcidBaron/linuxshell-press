#!/usr/bin/env bash
set -u

echo "=== SERVICES ==="
systemctl is-enabled kea-dhcp4-server
systemctl is-active kea-dhcp4-server
systemctl is-enabled isc-dhcp-server || true
systemctl is-active isc-dhcp-server || true

echo
echo "=== DHCP LISTENER ==="
sudo ss -lunp | grep ':67\b' || true

echo
echo "=== KEA CONFIG ==="
sudo kea-dhcp4 -t /etc/kea/kea-dhcp4.conf

echo
echo "=== RESERVATION ==="
grep -A8 -B2 '"reservations"' /etc/kea/kea-dhcp4.conf
