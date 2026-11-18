#!/usr/bin/env bash
set -euo pipefail

# Capitolo 15 - FreeIPA / IdM
# Eseguire una volta su ipa01 con un ticket Kerberos amministrativo valido:
#   kinit admin
#   bash policy/sudo-labadmins-whoami.sh

ipa sudocmd-add /usr/bin/whoami

ipa sudorule-add labadmins-whoami \
    --desc="Consente al gruppo labadmins di eseguire whoami con sudo su linux-client01"

ipa sudorule-add-user labadmins-whoami \
    --groups=labadmins

ipa sudorule-add-host labadmins-whoami \
    --hosts=linux-client01.lab.test

ipa sudorule-add-allow-command labadmins-whoami \
    --sudocmds=/usr/bin/whoami

ipa sudorule-show labadmins-whoami
