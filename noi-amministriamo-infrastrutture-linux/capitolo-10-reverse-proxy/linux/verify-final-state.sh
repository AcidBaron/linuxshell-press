#!/usr/bin/env bash
set -euo pipefail

echo '=== CH10 FINAL SERVER CHECKS ==='

echo 'rp01 expectations:'
echo '  nginx active on :80'
echo '  haproxy active on :8080'
echo '  ufw: 22/80/8080 from LAB-LAN'

echo 'web01 expectations:'
echo '  apache2 active on :80'
echo '  ufw: 22 from LAB-LAN; 80 only from 10.77.0.50'

echo 'client expectations:'
echo '  direct web01:80 from linux-client01 -> blocked'
echo '  sito1/sito2 via Nginx -> 200'
echo '  sito1/sito2 via HAProxy -> 200'
echo '  unknown HAProxy host -> 404'
echo '  direct backend IPv6 -> blocked'
