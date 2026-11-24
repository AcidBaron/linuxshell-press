# Rollback — Capitolo 20

## Checkpoint

Punto di ritorno iniziale: `CH20-PRE-NEXTCLOUD` su `web01`.

Stato finale validato: `CH20-NEXTCLOUD-COMPLETE` su `web01`, `rp01`, `infra01`. Al termine del laboratorio il checkpoint temporaneo è stato rimosso.

## infra01

Backup zona: `/etc/bind/db.lab.test.pre-ch20-nextcloud`.

```bash
sudo cp -a /etc/bind/db.lab.test.pre-ch20-nextcloud /etc/bind/db.lab.test
sudo named-checkzone lab.test /etc/bind/db.lab.test
sudo rndc reload lab.test
```

## rp01

Virtual host: `/etc/nginx/sites-available/nextcloud.conf`.
Backup pre-HSTS: `/etc/nginx/sites-available/nextcloud.conf.pre-hsts`.
La chiave privata TLS non viene versionata.

## web01

Applicazione e dati:

```text
/var/www/nextcloud
/var/lib/nextcloud-data
```

Database `nextcloud`; account MariaDB `nextcloud@localhost`.

Per un rollback completo del laboratorio preferire il checkpoint Hyper-V: rimuovere selettivamente applicazione, database, cron, Redis, moduli PHP e dati è più soggetto a errori.
