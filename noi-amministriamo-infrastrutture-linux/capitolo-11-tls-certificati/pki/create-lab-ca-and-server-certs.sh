#!/usr/bin/env bash
set -euo pipefail

BASE=/etc/ssl/linuxshell-lab-ca

sudo install -d -o root -g root -m 0755 "$BASE" "$BASE/certs" "$BASE/csr"
sudo install -d -o root -g root -m 0700 "$BASE/private"

sudo openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out "$BASE/private/linuxshell-lab-ca.key"
sudo chmod 600 "$BASE/private/linuxshell-lab-ca.key"

sudo openssl req -x509 -new -sha256 -days 3650 \
  -key "$BASE/private/linuxshell-lab-ca.key" \
  -out "$BASE/certs/linuxshell-lab-ca.crt" \
  -subj '/C=IT/O=Linuxshell Press/OU=Laboratorio/CN=Linuxshell Lab CA' \
  -addext 'basicConstraints=critical,CA:TRUE' \
  -addext 'keyUsage=critical,keyCertSign,cRLSign' \
  -addext 'subjectKeyIdentifier=hash'

for site in sito1 sito2; do
  sudo openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 \
    -out "$BASE/private/${site}.lab.test.key"
  sudo chmod 600 "$BASE/private/${site}.lab.test.key"

  sudo openssl req -new -sha256 \
    -key "$BASE/private/${site}.lab.test.key" \
    -out "$BASE/csr/${site}.lab.test.csr" \
    -subj "/C=IT/O=Linuxshell Press/OU=Laboratorio/CN=${site}.lab.test" \
    -addext "subjectAltName=DNS:${site}.lab.test"
done

sudo openssl x509 -req \
  -in "$BASE/csr/sito1.lab.test.csr" \
  -CA "$BASE/certs/linuxshell-lab-ca.crt" \
  -CAkey "$BASE/private/linuxshell-lab-ca.key" \
  -CAcreateserial -CAserial "$BASE/certs/linuxshell-lab-ca.srl" \
  -out "$BASE/certs/sito1.lab.test.crt" -days 825 -sha256 \
  -extfile "$BASE/csr/sito1.ext" -extensions server_cert

sudo openssl x509 -req \
  -in "$BASE/csr/sito2.lab.test.csr" \
  -CA "$BASE/certs/linuxshell-lab-ca.crt" \
  -CAkey "$BASE/private/linuxshell-lab-ca.key" \
  -CAserial "$BASE/certs/linuxshell-lab-ca.srl" \
  -out "$BASE/certs/sito2.lab.test.crt" -days 825 -sha256 \
  -extfile "$BASE/csr/sito2.ext" -extensions server_cert

echo 'Private keys remain local and must not be committed to Git.'
