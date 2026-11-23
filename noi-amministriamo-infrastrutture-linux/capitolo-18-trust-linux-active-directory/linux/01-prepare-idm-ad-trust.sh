#!/usr/bin/env bash
set -euo pipefail

# Capitolo 18 - Preparazione di ipa01 come AD trust controller
# La procedura contiene passaggi interattivi: kinit admin e ipa-adtrust-install.

kinit admin

ipa dnsforwardzone-add ad.lab.test \
    --forwarder=10.77.0.80 \
    --forward-policy=only

sudo cp -a \
    /etc/named/ipa-options-ext.conf \
    /etc/named/ipa-options-ext.conf.pre-ch18-ad-trust

sudo grep -n 'dnssec-validation' \
    /etc/named/ipa-options-ext.conf

sudo sed -i \
    's/^[[:space:]]*dnssec-validation[[:space:]].*;/dnssec-validation no;/' \
    /etc/named/ipa-options-ext.conf

sudo named-checkconf
sudo systemctl restart named

dig @127.0.0.1 \
    _ldap._tcp.dc._msdcs.ad.lab.test SRV \
    +comments +answer

sudo dnf install -y \
    freeipa-server-trust-ad \
    samba-client

kinit admin
sudo ipa-adtrust-install

sudo ipactl restart

IFACE=$(ip route show default | awk '/default/ {print $5; exit}')
ZONE=$(sudo firewall-cmd --get-zone-of-interface="$IFACE")

echo "Interfaccia: $IFACE"
echo "Zona firewalld: $ZONE"

sudo firewall-cmd \
    --zone="$ZONE" \
    --permanent \
    --add-service=freeipa-trust

sudo firewall-cmd --reload
