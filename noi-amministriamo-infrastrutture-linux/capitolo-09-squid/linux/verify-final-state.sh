#!/usr/bin/env bash
set -euo pipefail

echo "=== CH9 SQUID FINAL SERVER VERIFY ==="

echo
echo "--- VERSION / PACKAGE ---"
squid -v | head -n 3
dpkg-query -W -f='${Package}\t${Version}\n' squid squid-common apache2-utils

echo
echo "--- SERVICE ---"
systemctl is-enabled squid
systemctl is-active squid

echo
echo "--- CONFIG PARSE ---"
sudo squid -k parse

echo
echo "--- LISTENER ---"
sudo ss -ltnp | grep ':3128\b'

echo
echo "--- UFW ---"
sudo ufw status verbose

echo
echo "--- FILES ---"
sudo test -r /etc/squid/lists/blocked-domains.txt
sudo test -r /etc/squid/passwd
sudo cat /etc/squid/lists/blocked-domains.txt
sudo cut -d: -f1 /etc/squid/passwd

echo
echo "--- CACHE ---"
sudo du -sh /var/spool/squid
sudo grep -E 'Objects loaded|Entries scanned|store_swap_size|Finished rebuilding' /var/log/squid/cache.log | tail -n 10 || true

echo
echo "Server verification completed."
echo "Client expectations: 407 no-auth; 200 allowed; TCP_TUNNEL/200 HTTPS; 403 blocked domain."
