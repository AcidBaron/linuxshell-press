#!/usr/bin/env bash
set -euo pipefail

sudo ufw default deny incoming
sudo ufw default allow outgoing

sudo ufw allow from 10.77.0.0/24 to any port 22 proto tcp comment 'LAB-LAN SSH'
sudo ufw allow from 10.77.0.0/24 to any port 80 proto tcp comment 'LAB-LAN Nginx reverse proxy'
sudo ufw allow from 10.77.0.0/24 to any port 8080 proto tcp comment 'LAB-LAN HAProxy'

sudo ufw --force enable
sudo ufw status verbose
sudo ufw status numbered
