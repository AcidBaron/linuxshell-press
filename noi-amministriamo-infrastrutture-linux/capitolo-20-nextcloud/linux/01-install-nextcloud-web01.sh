#!/usr/bin/env bash
set -euo pipefail

# Eseguire su web01. Password LAB ONLY.
NC_VERSION=35.0.3
DB_PASS='123456Aa!'
ADMIN_PASS='123456Aa!'

sudo apt update
sudo apt install -y \
    mariadb-server \
    libapache2-mod-php8.3 \
    php8.3-cli php8.3-gd php8.3-mysql php8.3-curl \
    php8.3-mbstring php8.3-intl php8.3-gmp php8.3-xml \
    php8.3-zip php-imagick bzip2

sudo mariadb <<SQL
CREATE USER IF NOT EXISTS 'nextcloud'@'localhost' IDENTIFIED BY '${DB_PASS}';
CREATE DATABASE IF NOT EXISTS nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'localhost';
FLUSH PRIVILEGES;
SQL

cd /tmp
wget "https://download.nextcloud.com/server/releases/nextcloud-${NC_VERSION}.tar.bz2"
wget "https://download.nextcloud.com/server/releases/nextcloud-${NC_VERSION}.tar.bz2.sha256"
grep "nextcloud-${NC_VERSION}.tar.bz2" "nextcloud-${NC_VERSION}.tar.bz2.sha256" | sha256sum -c -
tar -xjf "nextcloud-${NC_VERSION}.tar.bz2"

[[ ! -e /var/www/nextcloud ]] || { echo '/var/www/nextcloud already exists' >&2; exit 1; }
sudo cp -a nextcloud /var/www/
sudo chown -R www-data:www-data /var/www/nextcloud
sudo install -d -o www-data -g www-data -m 0750 /var/lib/nextcloud-data

sudo a2ensite nextcloud.conf
sudo a2enmod rewrite headers env dir mime
sudo apache2ctl configtest
sudo systemctl reload apache2

sudo -E -u www-data php /var/www/nextcloud/occ maintenance:install \
    --database mysql \
    --database-name nextcloud \
    --database-host localhost \
    --database-user nextcloud \
    --database-pass "${DB_PASS}" \
    --admin-user admin \
    --admin-pass "${ADMIN_PASS}" \
    --data-dir /var/lib/nextcloud-data

sudo -E -u www-data php /var/www/nextcloud/occ status
