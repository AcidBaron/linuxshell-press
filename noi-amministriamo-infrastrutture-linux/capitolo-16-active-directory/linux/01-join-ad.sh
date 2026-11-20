#!/usr/bin/env bash
set -euo pipefail

# Capitolo 16 - Join di linux-client01 ad Active Directory
# Eseguire sulla baseline CH15-PRE-FREEIPA-ENROLLMENT.
# realm join richiede interattivamente la password LAB ONLY di Administrator.

sudo cp -a     /etc/sssd/sssd.conf     /etc/sssd/sssd.conf.pre-ch16-ad

sudo apt update
sudo apt install -y     sssd-ad     sssd-tools     realmd     adcli     samba-common-bin

sudo realm -v discover ad.lab.test
sudo realm join -v -U Administrator ad.lab.test

realm list

sudo grep -E '^\[sssd\]|^domains|^\[domain/|^id_provider|^ad_domain|^krb5_realm|^ldap_uri' /etc/sssd/sssd.conf

getent passwd ldapuser01
id 'Administrator@ad.lab.test'

sudo pam-auth-update --enable mkhomedir
sudo systemctl restart sssd
