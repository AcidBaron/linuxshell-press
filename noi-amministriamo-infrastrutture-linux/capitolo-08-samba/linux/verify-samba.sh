#!/usr/bin/env bash
set -u

echo "=== SERVICE ==="
systemctl is-enabled smbd
systemctl is-active smbd

echo
echo "=== CONFIG ==="
sudo testparm -s
echo "testparm_exit=$?"

echo
echo "=== LISTENER TCP/445 ==="
sudo ss -lntp | grep ':445'

echo
echo "=== FIREWALL ==="
sudo ufw status verbose

echo
echo "=== LOCAL SHARE TEST ==="
smbclient -L //10.77.0.20 -U smbuser
smbclient //10.77.0.20/dati -U smbuser -c 'ls'
