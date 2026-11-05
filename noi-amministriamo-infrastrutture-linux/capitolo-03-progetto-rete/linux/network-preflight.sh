#!/usr/bin/env bash
set -u

echo "=== ADDRESS / ROUTING ==="
ip -br -4 addr
ip -4 route
ip route get 1.1.1.1

echo
echo "=== NEIGHBORS ==="
ip neigh

echo
echo "=== PRE-DNS FAILURE TEST ==="
for name in fw01.lab.test infra01.lab.test linux-client01.lab.test; do
    getent ahostsv4 "$name"
    echo "$name exit=$?"
done
