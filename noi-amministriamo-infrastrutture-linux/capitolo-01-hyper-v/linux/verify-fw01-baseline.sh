#!/usr/bin/env bash
set -u

echo "=== FW01 BASELINE ==="
hostname
ip -br addr
ip route

echo
echo "=== CONNECTIVITY ==="
ping -c 3 10.77.0.254 || true
ping -c 3 1.1.1.1
getent hosts archive.ubuntu.com

echo
echo "=== OPENSSH ==="
dpkg -l openssh-server | grep '^ii'
systemctl status ssh.socket --no-pager
systemctl is-enabled ssh.socket
systemctl is-active ssh.socket
sudo ss -ltnp | grep ':22'
