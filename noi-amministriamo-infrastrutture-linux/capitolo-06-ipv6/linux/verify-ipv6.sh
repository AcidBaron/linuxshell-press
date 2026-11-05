#!/usr/bin/env bash
set -u

echo "=== NETPLAN ==="
sudo netplan generate

echo
echo "=== RADVD ==="
sudo radvd -c -C /etc/radvd.conf
systemctl is-active radvd

echo
echo "=== NFTABLES ==="
sudo nft -c -f /etc/nftables.conf
systemctl is-active nftables

echo
echo "=== IPv6 ROUTING ==="
sysctl net.ipv6.conf.all.forwarding
ip -br -6 addr
ip -6 route
ip -6 neigh

echo
echo "=== BIND ==="
sudo named-checkconf
sudo named-checkzone lab.test /etc/bind/db.lab.test
sudo named-checkzone 1.0.0.0.1.9.d.2.c.4.b.7.a.3.d.f.ip6.arpa /etc/bind/db.fd3a-7b4c-2d91-1
