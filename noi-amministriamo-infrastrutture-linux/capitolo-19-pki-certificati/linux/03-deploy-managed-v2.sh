#!/usr/bin/env bash
set -euo pipefail

BASE=/etc/ssl/linuxshell-lab-ca
ISSUING=$BASE/issuing-ca

sudo cp -a \
    /etc/nginx/tls/sito1.lab.test.crt \
    /etc/nginx/tls/sito1.lab.test.crt.pre-ch19

sudo cp -a \
    /etc/nginx/tls/sito1.lab.test.key \
    /etc/nginx/tls/sito1.lab.test.key.pre-ch19

sudo sh -c \
    "cat \
    '$ISSUING/certs/sito1.lab.test.managed-v2.crt' \
    '$ISSUING/certs/linuxshell-lab-issuing-ca.crt' \
    > /etc/nginx/tls/sito1.lab.test.crt"

sudo install \
    -o root \
    -g root \
    -m 0600 \
    "$ISSUING/private/sito1.lab.test.managed-v2.key" \
    /etc/nginx/tls/sito1.lab.test.key

sudo nginx -t
sudo systemctl reload nginx

sudo cp -a \
    /etc/haproxy/certs/sito1.lab.test.pem \
    /etc/haproxy/certs/sito1.lab.test.pem.pre-ch19

sudo sh -c \
    "cat \
    '$ISSUING/certs/sito1.lab.test.managed-v2.crt' \
    '$ISSUING/certs/linuxshell-lab-issuing-ca.crt' \
    '$ISSUING/private/sito1.lab.test.managed-v2.key' \
    > /etc/haproxy/certs/sito1.lab.test.pem"

sudo chown root:root \
    /etc/haproxy/certs/sito1.lab.test.pem

sudo chmod 600 \
    /etc/haproxy/certs/sito1.lab.test.pem

sudo haproxy -c \
    -f /etc/haproxy/haproxy.cfg

sudo systemctl reload haproxy
