#!/usr/bin/env bash
set -euo pipefail

sudo ufw allow from 10.77.0.0/24 to any port 443 proto tcp comment 'LAB-LAN Nginx HTTPS'
sudo ufw allow from 10.77.0.0/24 to any port 8443 proto tcp comment 'LAB-LAN HAProxy HTTPS'
sudo ufw status numbered
