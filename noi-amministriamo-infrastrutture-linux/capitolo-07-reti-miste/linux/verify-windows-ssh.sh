#!/usr/bin/env bash
set -u

echo "=== WINDOWS SSH FROM LINUX ==="
nc -vz 10.77.0.254 22
nc -vz fd3a:7b4c:2d91:1:c1f1:f445:e784:4ff4 22

echo
echo "Login examples:"
echo "ssh Utente@10.77.0.254"
echo "ssh Utente@fd3a:7b4c:2d91:1:c1f1:f445:e784:4ff4"
