#!/usr/bin/env bash
set -euo pipefail

BASE=/etc/ssl/linuxshell-lab-ca
ISSUING=$BASE/issuing-ca

issue_cert() {
    local ver="$1"

    sudo openssl genpkey         -algorithm RSA         -pkeyopt rsa_keygen_bits:2048         -out "$ISSUING/private/sito1.lab.test.managed-${ver}.key"

    sudo chmod 600 "$ISSUING/private/sito1.lab.test.managed-${ver}.key"

    sudo openssl req         -new         -sha256         -key "$ISSUING/private/sito1.lab.test.managed-${ver}.key"         -out "$ISSUING/csr/sito1.lab.test.managed-${ver}.csr"         -subj '/C=IT/O=Linuxshell Press/OU=Laboratorio/CN=sito1.lab.test'         -addext 'subjectAltName=DNS:sito1.lab.test'

    sudo openssl ca         -batch         -config "$ISSUING/openssl.cnf"         -extensions server_cert         -in "$ISSUING/csr/sito1.lab.test.managed-${ver}.csr"         -out "$ISSUING/certs/sito1.lab.test.managed-${ver}.crt"

    sudo openssl verify         -CAfile "$BASE/certs/linuxshell-lab-ca.crt"         -untrusted "$ISSUING/certs/linuxshell-lab-issuing-ca.crt"         "$ISSUING/certs/sito1.lab.test.managed-${ver}.crt"
}

issue_cert v1
issue_cert v2

sudo openssl ca     -config "$ISSUING/openssl.cnf"     -revoke "$ISSUING/certs/sito1.lab.test.managed-v1.crt"     -crl_reason superseded

sudo openssl ca     -config "$ISSUING/openssl.cnf"     -gencrl     -out "$ISSUING/crl/linuxshell-lab-issuing-ca.crl"

echo "=== CA database ==="
sudo cat "$ISSUING/index.txt"
echo "=== next serial ==="
sudo cat "$ISSUING/serial"
echo "=== next CRL number ==="
sudo cat "$ISSUING/crlnumber"

sudo openssl verify     -CAfile "$BASE/certs/linuxshell-lab-ca.crt"     -untrusted "$ISSUING/certs/linuxshell-lab-issuing-ca.crt"     -CRLfile "$ISSUING/crl/linuxshell-lab-issuing-ca.crl"     -crl_check     "$ISSUING/certs/sito1.lab.test.managed-v1.crt" || true

sudo openssl verify     -CAfile "$BASE/certs/linuxshell-lab-ca.crt"     -untrusted "$ISSUING/certs/linuxshell-lab-issuing-ca.crt"     -CRLfile "$ISSUING/crl/linuxshell-lab-issuing-ca.crl"     -crl_check     "$ISSUING/certs/sito1.lab.test.managed-v2.crt"
