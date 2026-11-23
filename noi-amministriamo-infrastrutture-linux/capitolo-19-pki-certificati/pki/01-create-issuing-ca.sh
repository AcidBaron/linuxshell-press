#!/usr/bin/env bash
set -euo pipefail

BASE=/etc/ssl/linuxshell-lab-ca
ISSUING=$BASE/issuing-ca

if [[ -e "$ISSUING/private/linuxshell-lab-issuing-ca.key" ]]; then
    echo "Issuing CA key already exists: refusing to overwrite." >&2
    exit 1
fi

sudo install -d -o root -g root -m 0755 \
    "$ISSUING" \
    "$ISSUING/certs" \
    "$ISSUING/crl" \
    "$ISSUING/csr" \
    "$ISSUING/newcerts"

sudo install -d -o root -g root -m 0700 \
    "$ISSUING/private"

sudo install -o root -g root -m 0644 \
    /dev/null \
    "$ISSUING/index.txt"

printf '1000\n' |
    sudo tee "$ISSUING/serial" >/dev/null

printf '1000\n' |
    sudo tee "$ISSUING/crlnumber" >/dev/null

sudo install -o root -g root -m 0644 \
    "$(dirname "$0")/openssl.cnf" \
    "$ISSUING/openssl.cnf"

sudo install -o root -g root -m 0644 \
    "$(dirname "$0")/intermediate.ext" \
    "$ISSUING/intermediate.ext"

sudo openssl genpkey \
    -algorithm RSA \
    -pkeyopt rsa_keygen_bits:4096 \
    -out "$ISSUING/private/linuxshell-lab-issuing-ca.key"

sudo chmod 600 \
    "$ISSUING/private/linuxshell-lab-issuing-ca.key"

sudo openssl req \
    -new \
    -sha256 \
    -key "$ISSUING/private/linuxshell-lab-issuing-ca.key" \
    -out "$ISSUING/csr/linuxshell-lab-issuing-ca.csr" \
    -subj '/C=IT/O=Linuxshell Press/OU=Laboratorio/CN=Linuxshell Lab Issuing CA'

sudo openssl x509 \
    -req \
    -in "$ISSUING/csr/linuxshell-lab-issuing-ca.csr" \
    -CA "$BASE/certs/linuxshell-lab-ca.crt" \
    -CAkey "$BASE/private/linuxshell-lab-ca.key" \
    -CAserial "$BASE/certs/linuxshell-lab-ca.srl" \
    -out "$ISSUING/certs/linuxshell-lab-issuing-ca.crt" \
    -days 1825 \
    -sha256 \
    -extfile "$ISSUING/intermediate.ext" \
    -extensions v3_intermediate_ca

sudo sh -c \
    "cat \
    '$ISSUING/certs/linuxshell-lab-issuing-ca.crt' \
    '$BASE/certs/linuxshell-lab-ca.crt' \
    > '$ISSUING/certs/linuxshell-lab-ca-chain.crt'"

sudo openssl verify \
    -CAfile "$BASE/certs/linuxshell-lab-ca.crt" \
    "$ISSUING/certs/linuxshell-lab-issuing-ca.crt"
