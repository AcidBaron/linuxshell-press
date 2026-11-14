# Rollback – Capitolo 10

Il laboratorio è stato chiuso con checkpoint Hyper-V e backup BIND. Il rollback è documentato per sicurezza; lo stato finale validato è quello da preservare.

## Checkpoint

- `CH10-RP01-PRE-REVERSE-PROXY`
- `CH10-WEB01-PRE-APACHE`
- `CH10-WEB01-VHOSTS-VALIDATED`
- `CH10-NGINX-REVERSE-PROXY-VALIDATED`
- `CH10-WEB01-PROXY-LOGS-VALIDATED`
- `CH10-RP01-FINAL-VALIDATED`
- `CH10-WEB01-FINAL-VALIDATED`

Per tornare allo stato precedente al Capitolo 10 usare i checkpoint PRE delle rispettive VM.

## BIND

Backup creati prima dei record del Capitolo 10:

- `/etc/bind/db.lab.test.pre-ch10-reverse-proxy`
- `/etc/bind/db.10.77.0.pre-ch10-reverse-proxy`

Per il ripristino: copiare i backup sui file di zona correnti, validare con `named-checkzone` e ricaricare BIND con `rndc reload`.

## Nginx

Rimuovere i link da `/etc/nginx/sites-enabled/`, ripristinare il sito desiderato e validare sempre con `nginx -t` prima del reload.

## HAProxy

Il file package-default può essere salvato prima della modifica come `/etc/haproxy/haproxy.cfg.pkg-default`. Prima del restart validare con `haproxy -c -f /etc/haproxy/haproxy.cfg`.

## Apache

I file del capitolo sono sotto `/etc/apache2/conf-available/` e `/etc/apache2/sites-available/`. Prima del reload usare `apache2ctl configtest`.
