# Preparare proxy01 come standby Nginx

**Macchine:** PC Windows Hyper-V, rp01, proxy01, web01, linux-client01.

Stato iniziale: proxy01=10.77.0.40 esegue Squid/3128; rp01=10.77.0.50 esegue già Nginx/HTTPS per Nextcloud; web01=10.77.0.51 accetta Apache HTTP solo da rp01.

## Selezione e checkpoint

PowerShell amministrativa sull'host Hyper-V:

```powershell
Get-VM -Name "rp01","proxy01" |
    Select-Object Name,State,ProcessorCount,MemoryAssigned

Get-VMNetworkAdapter -VMName "rp01","proxy01" |
    Format-Table VMName,SwitchName,Status

Checkpoint-VM `
    -Name "proxy01" `
    -SnapshotName "CH22-PRE-HA-STANDBY"
```

Su proxy01, Bash, è stato verificato che 80/443 fossero libere:

```bash
sudo ss -ltnp |
    grep -E ':(80|443|3128)[[:space:]]'

sudo apt update
sudo apt install -y nginx
systemctl is-active squid
systemctl is-active nginx
sudo nginx -t
```

Entrambi i servizi risultavano active e Nginx aveva configurazione valida.

## Copia privata e temporanea del VirtualHost e del certificato

**Su rp01, Bash:**

```bash
sudo tar \
    -C /etc/nginx \
    -czf /home/labadmin/ch22-nextcloud-standby.tar.gz \
    sites-available/nextcloud.conf \
    tls/nextcloud.lab.test.crt \
    tls/nextcloud.lab.test.key

sudo chown labadmin:labadmin \
    /home/labadmin/ch22-nextcloud-standby.tar.gz
sudo chmod 600 \
    /home/labadmin/ch22-nextcloud-standby.tar.gz
```

**Su proxy01, Bash** (attenzione a non eseguire il trasferimento sulla stessa rp01):

```bash
scp \
    labadmin@10.77.0.50:/home/labadmin/ch22-nextcloud-standby.tar.gz \
    ~/

sudo tar -C /etc/nginx \
    -xzf ~/ch22-nextcloud-standby.tar.gz

sudo chown root:root /etc/nginx/tls/nextcloud.lab.test.key
sudo chmod 600 /etc/nginx/tls/nextcloud.lab.test.key

sudo ln -s \
    /etc/nginx/sites-available/nextcloud.conf \
    /etc/nginx/sites-enabled/nextcloud.conf

sudo nginx -t
sudo systemctl reload nginx
```

Non caricare l'archivio, la chiave privata o il PEM contenente la chiave su GitHub. La copia temporanea va eliminata da entrambe le VM dopo il trasferimento:

```bash
rm -f ~/ch22-nextcloud-standby.tar.gz
```

## Accesso al backend

**Su web01, Bash:**

```bash
sudo ufw allow \
    from 10.77.0.40 \
    to any port 80 \
    proto tcp \
    comment 'CH22 standby proxy01'

cd /var/www/nextcloud
sudo -E -u www-data php occ config:system:set \
    trusted_proxies \
    --type=json \
    --value='["10.77.0.50","10.77.0.40"]'
```

**Su proxy01, Bash:**

```bash
sudo ufw allow \
    from 10.77.0.0/24 \
    to any port 80 \
    proto tcp \
    comment 'CH22 Nginx HTTP'

sudo ufw allow \
    from 10.77.0.0/24 \
    to any port 443 \
    proto tcp \
    comment 'CH22 Nginx HTTPS'
```

**Su linux-client01, Bash:**

```bash
curl -I \
    --resolve nextcloud.lab.test:443:10.77.0.40 \
    https://nextcloud.lab.test/
```

Risultato validato: HTTP 302 verso https://nextcloud.lab.test/index.php/login, HSTS max-age=15552000, senza modificare ancora il DNS.
