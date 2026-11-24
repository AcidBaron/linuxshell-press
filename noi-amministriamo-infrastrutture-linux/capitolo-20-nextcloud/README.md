# Capitolo 20 — Servizi self-hosted: Nextcloud

Materiale operativo del Capitolo 20 di **Noi Amministriamo Infrastrutture Linux**.

Il laboratorio installa Nextcloud 35.0.3 riutilizzando esclusivamente VM e servizi già costruiti nei capitoli precedenti.

## Architettura validata

- `web01` — `10.77.0.51`: Apache, PHP 8.3, MariaDB 10.11, Nextcloud 35.0.3, Redis/APCu.
- `rp01` — `10.77.0.50`: Nginx reverse proxy e terminazione HTTPS.
- `infra01`: DNS autorevole `lab.test`.
- `linux-client01`: client di verifica.
- URL: `https://nextcloud.lab.test`.

Nessuna nuova VM è stata creata.

## Stato finale validato

- installazione CLI con `occ maintenance:install`;
- database MariaDB dedicato;
- data directory `/var/lib/nextcloud-data`;
- trusted domain/proxy configurati;
- certificato emesso dalla Linuxshell Lab Issuing CA;
- cron ogni 5 minuti;
- APCu + Redis e transactional file locking;
- HSTS;
- WebDAV upload/download verificato byte-per-byte;
- public share via OCS API verificata;
- checkpoint finale `CH20-NEXTCLOUD-COMPLETE` su `web01`, `rp01`, `infra01`.

## File

- `apache/nextcloud.conf` — virtual host interno di web01.
- `nginx/nextcloud.conf` — reverse proxy HTTPS su rp01.
- `linux/01-install-nextcloud-web01.sh` — stack e installazione CLI.
- `linux/02-configure-nextcloud.sh` — proxy settings, cron, APCu/Redis, repair.
- `dns/01-add-nextcloud-record.sh` — record DNS e seriale SOA.
- `pki/01-issue-nextcloud-cert.sh` — certificato dalla Issuing CA del Capitolo 19.
- `linux/03-functional-tests.sh` — WebDAV e OCS Share API.
- `optional/smb-external-storage-NOT-VALIDATED.md` — estensione SMB indicativa, non verificata.
- `rollback/README.md` — rollback.

## Troubleshooting validato

### bzip2 assente

`tar -xjf` falliva con `bzip2: Cannot exec`; il checksum era corretto. Correzione:

```bash
sudo apt install -y bzip2
```

### Password rifiutata

La password LAB `123456Aa!` è stata accettata per database e amministratore durante l'installazione, ma è stata rifiutata per il nuovo utente perché presente nella lista di password compromesse. Per `ncuser01` è stata usata la password LAB `provadipasswordnextcloud`.

### Fontconfig

Durante `occ user:add` sono comparsi warning `Fontconfig error: No writable cache directories`; l'account è stato comunque creato e non è stata aperta una diagnostica senza sintomo funzionale.

### Setup checks

Dopo le correzioni risultano PASS cron, maintenance window, memcache, transactional file locking, mimetype migrations, WebDAV, HTTPS e security headers. Il warning aggregato database è rimasto senza finding concreti: i controlli sottostanti erano tutti `success`, quindi non è stato applicato tuning MariaDB non motivato.

## Sicurezza

Le password riportate sono LAB ONLY. Non versionare chiavi private TLS, secret crittografici, credenziali reali o PEM contenenti chiavi private.
