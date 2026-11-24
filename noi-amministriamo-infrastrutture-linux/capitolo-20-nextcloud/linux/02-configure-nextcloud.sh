#!/usr/bin/env bash
set -euo pipefail

cd /var/www/nextcloud

sudo -E -u www-data php occ config:system:set trusted_domains --type=json --value='["nextcloud.lab.test"]'
sudo -E -u www-data php occ config:system:set trusted_proxies --type=json --value='["10.77.0.50"]'
sudo -E -u www-data php occ config:system:set forwarded_for_headers --type=json --value='["HTTP_X_FORWARDED_FOR"]'
sudo -E -u www-data php occ config:system:set overwriteprotocol --value=https
sudo -E -u www-data php occ config:system:set overwrite.cli.url --value=https://nextcloud.lab.test

sudo -E -u www-data php occ background:cron
(
    sudo crontab -u www-data -l 2>/dev/null | grep -v '/var/www/nextcloud/cron.php' || true
    echo '*/5 * * * * php -f /var/www/nextcloud/cron.php'
) | sudo crontab -u www-data -
sudo -E -u www-data php /var/www/nextcloud/cron.php
sudo -E -u www-data php occ config:system:set maintenance_window_start --type=integer --value=1

sudo apt install -y php8.3-apcu redis-server php8.3-redis
sudo tee /etc/php/8.3/mods-available/nextcloud-apcu.ini >/dev/null <<'EOF'
apc.enable_cli=1
EOF
sudo phpenmod nextcloud-apcu
sudo systemctl restart apache2

sudo -E -u www-data php occ config:system:set memcache.local --value='\OC\Memcache\APCu'
sudo -E -u www-data php occ config:system:set memcache.distributed --value='\OC\Memcache\Redis'
sudo -E -u www-data php occ config:system:set memcache.locking --value='\OC\Memcache\Redis'
sudo -E -u www-data php occ config:system:set redis host --value=127.0.0.1
sudo -E -u www-data php occ config:system:set redis port --type=integer --value=6379
sudo -E -u www-data php occ maintenance:repair --include-expensive
sudo -E -u www-data php occ setupchecks
