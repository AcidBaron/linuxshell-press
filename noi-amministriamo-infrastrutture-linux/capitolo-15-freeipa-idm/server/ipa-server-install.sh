#!/usr/bin/env bash
set -euo pipefail

# Capitolo 15 - FreeIPA / IdM
# LAB ONLY: le password numeriche sono credenziali didattiche dichiarate.
#
# Eseguire su ipa01:
#   sudo bash server/ipa-server-install.sh

umask 0022

ipa-server-install \
    --unattended \
    --hostname=ipa01.idm.lab.test \
    --ip-address=10.77.0.70 \
    --domain=idm.lab.test \
    --realm=IDM.LAB.TEST \
    --ds-password=12345678 \
    --admin-password=12345678 \
    --setup-dns \
    --forwarder=10.77.0.10 \
    --no-reverse \
    --no-ntp
