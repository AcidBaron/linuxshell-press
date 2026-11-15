#!/usr/bin/env bash
set -euo pipefail

CA_SOURCE=${1:-/tmp/linuxshell-lab-ca.crt}
CA_TARGET=/usr/local/share/ca-certificates/linuxshell-lab-ca.crt

sudo install -o root -g root -m 0644 "$CA_SOURCE" "$CA_TARGET"
sudo update-ca-certificates

openssl x509 -in "$CA_TARGET" -noout -subject -issuer -fingerprint -sha256
