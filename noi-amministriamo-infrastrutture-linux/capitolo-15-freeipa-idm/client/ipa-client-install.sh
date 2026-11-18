#!/usr/bin/env bash
set -euo pipefail

# Capitolo 15 - FreeIPA / IdM
# LAB ONLY: la password numerica è una credenziale didattica dichiarata.
#
# Prerequisiti:
# - freeipa-client installato;
# - ipa01.idm.lab.test risolve a 10.77.0.70;
# - LDAP per hostname risponde.
#
# Eseguire su linux-client01:
#   sudo bash client/ipa-client-install.sh

ipa-client-install \
    --unattended \
    --hostname=linux-client01.lab.test \
    --domain=idm.lab.test \
    --realm=IDM.LAB.TEST \
    --server=ipa01.idm.lab.test \
    --principal=admin \
    --password=12345678 \
    --mkhomedir \
    --no-ntp \
    --no-dns-sshfp
