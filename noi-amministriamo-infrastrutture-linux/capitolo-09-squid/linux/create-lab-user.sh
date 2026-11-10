#!/usr/bin/env bash
set -euo pipefail

# Capitolo 9 - utente NCSA del laboratorio
# Il libro usa proxyuser con password didattica 123.
# La password viene richiesta interattivamente e non e memorizzata nello script.

if ! command -v htpasswd >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y apache2-utils
fi

sudo htpasswd -c /etc/squid/passwd proxyuser
sudo chown root:proxy /etc/squid/passwd
sudo chmod 640 /etc/squid/passwd

sudo ls -l /etc/squid/passwd
sudo cut -d: -f1 /etc/squid/passwd
