#!/usr/bin/env bash
set -euo pipefail

echo '=== CH11 FINAL CHECKLIST ==='
echo 'rp01: nginx active on 80/443; haproxy active on 8080/8443'
echo 'web01: apache2 active on 80; backend still isolated from clients'
echo 'linux-client01: Linuxshell Lab CA installed in trust store'
echo 'sito1/sito2 HTTPS via Nginx: expected 200 without -k'
echo 'sito1/sito2 HTTPS via HAProxy: expected 200 without -k'
echo 'TLS 1.2 and TLS 1.3: expected verify return code 0'
echo 'Apache logs: forwarded client 10.77.0.101; proto http/https according to frontend'
