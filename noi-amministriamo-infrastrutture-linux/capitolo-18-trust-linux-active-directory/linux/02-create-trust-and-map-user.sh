#!/usr/bin/env bash
set -euo pipefail

# Capitolo 18 - Creazione trust e mapping utente AD
# Passaggi interattivi: password AD Administrator e domande di group-add-member.

smbclient \
    -L //dc01.ad.lab.test \
    -U 'AD\\Administrator'

kinit admin

ipa trust-add \
    --type=ad \
    ad.lab.test \
    --admin Administrator \
    --password \
    --range-type=ipa-ad-trust

ipa trust-fetch-domains ad.lab.test

id 'aduser01@ad.lab.test'

ipa group-add \
    --desc='Utenti AD - mapping esterno' \
    ad_users_external \
    --external

ipa group-add \
    --desc='Utenti AD autorizzati in IdM' \
    ad_users

ipa group-add-member \
    ad_users_external \
    --external 'aduser01@ad.lab.test'

ipa group-add-member \
    ad_users \
    --groups ad_users_external

sudo sssctl cache-expire \
    -u 'aduser01@ad.lab.test'

id 'aduser01@ad.lab.test'
