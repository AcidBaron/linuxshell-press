#!/usr/bin/env bash
set -euo pipefail

# Capitolo 15 - FreeIPA / IdM
# Correzione validata sul linux-client01 riutilizzato dal Capitolo 14.
#
# Il client aveva contemporaneamente:
#   services = ssh, sudo, nss, pam
# e sssd-sudo.socket abilitato.
#
# Manteniamo il responder sudo socket-activated e rimuoviamo "sudo"
# dalla riga services.
#
# Eseguire su linux-client01:
#   sudo bash client/sssd-sudo-fix.sh

cp -a \
    /etc/sssd/sssd.conf \
    /etc/sssd/sssd.conf.pre-ch15-sudo-fix

sed -i '/^services = /s/, sudo//' /etc/sssd/sssd.conf

grep '^services' /etc/sssd/sssd.conf

systemctl restart sssd
systemctl reset-failed sssd-sudo.socket
systemctl start sssd-sudo.socket

systemctl is-active sssd
systemctl is-active sssd-sudo.socket
