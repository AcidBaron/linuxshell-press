#!/usr/bin/env bash
set -euo pipefail

BASE=/etc/ssl/linuxshell-lab-ca
ISSUING=$BASE/issuing-ca

[[ ! -e "$ISSUING/private/nextcloud.lab.test.key" ]] || { echo 'Private key already exists' >&2; exit 1; }

sudo openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 \
    -out "$ISSUING/private/nextcloud.lab.test.key"
sudo chmod 600 "$ISSUING/private/nextcloud.lab.test.key"

sudo openssl req -new -sha256 \
    -key "$ISSUING/private/nextcloud.lab.test.key" \
    -out "$ISSUING/csr/nextcloud.lab.test.csr" \
    -subj '/C=IT/O=Linuxshell Press/OU=Laboratorio/CN=nextcloud.lab.test' \
    -addext 'subjectAltName=DNS:nextcloud.lab.test'

sudo openssl ca -batch -config "$ISSUING/openssl.cnf" -extensions server_cert \
    -in "$ISSUING/csr/nextcloud.lab.test.csr" \
    -out "$ISSUING/certs/nextcloud.lab.test.crt"

sudo openssl verify \
    -CAfile "$BASE/certs/linuxshell-lab-ca.crt" \
    -untrusted "$ISSUING/certs/linuxshell-lab-issuing-ca.crt" \
    "$ISSUING/certs/nextcloud.lab.test.crt"
