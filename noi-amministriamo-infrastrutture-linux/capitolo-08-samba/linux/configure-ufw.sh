#!/usr/bin/env bash
set -euo pipefail

sudo ufw default deny incoming
sudo ufw default allow outgoing

sudo ufw allow from 10.77.0.0/24 to any port 22 proto tcp
sudo ufw allow from 10.77.0.0/24 to any port 445 proto tcp

sudo ufw allow from fd3a:7b4c:2d91:1::/64 to any port 22 proto tcp
sudo ufw allow from fd3a:7b4c:2d91:1::/64 to any port 445 proto tcp

sudo ufw --force enable
sudo ufw status numbered
sudo ufw status verbose
