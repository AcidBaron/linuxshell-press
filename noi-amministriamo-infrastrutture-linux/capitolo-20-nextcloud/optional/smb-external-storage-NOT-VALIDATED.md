# Storage SMB esterno — NON VERIFICATO nel Capitolo 20

Questa estensione è intenzionalmente fuori dal laboratorio validato.

Nextcloud può usare una share SMB/CIFS tramite l'app bundled **External Storage Support**. Nel nostro ambiente l'integrazione naturale sarebbe `files01` (`10.77.0.20`) e la share `dati`.

Prerequisiti indicativi:

```bash
sudo apt install -y \
    smbclient \
    php-smbclient

sudo systemctl restart apache2

cd /var/www/nextcloud
sudo -E -u www-data php occ app:enable files_external
```

Poi configurare da **Impostazioni → Amministrazione → Storage esterno** un backend SMB/CIFS con host, share e credenziali.

Questa procedura non è stata eseguita né validata nel Capitolo 20 e deve essere verificata prima dell'uso operativo.
