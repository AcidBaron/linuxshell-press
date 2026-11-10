#!/usr/bin/env bash
set -euo pipefail

# Capitolo 9 - firewall finale proxy01
sudo ufw default deny incoming
sudo ufw default allow outgoing

sudo ufw allow from 10.77.0.0/24 to any port 22 proto tcp comment 'LAB-LAN SSH'
sudo ufw allow from 10.77.0.0/24 to any port 3128 proto tcp comment 'LAB-LAN Squid'

sudo ufw --force enable
sudo ufw status verbose
sudo ufw status numbered
