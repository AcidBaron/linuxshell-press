#!/usr/bin/env bash
set -euo pipefail

sudo systemctl disable --now isc-dhcp-server
sudo cp -a /etc/kea/kea-dhcp4.conf.KEA-STABLE-FINAL /etc/kea/kea-dhcp4.conf
sudo kea-dhcp4 -t /etc/kea/kea-dhcp4.conf
sudo systemctl enable --now kea-dhcp4-server
systemctl is-active kea-dhcp4-server
sudo ss -lunp | grep ':67\b'
