# Rollback – Capitolo 9

Il laboratorio finale è stato validato con checkpoint Hyper-V e backup espliciti. Il rollback è documentato ma non è stato eseguito avanti/indietro, perché lo stato finale è quello da preservare.

## Hyper-V

Checkpoint disponibili:

- `CH9-PROXY01-PRE-SQUID`
- `CH9-SQUID-BASIC-VALIDATED`
- `CH9-SQUID-UFW-VALIDATED`
- `CH9-SQUID-DISK-CACHE-VALIDATED`
- `CH9-SQUID-DOMAIN-ACL-VALIDATED`
- `CH9-SQUID-AUTH-VALIDATED`
- `CH9-SQUID-FINAL-VALIDATED`

Per tornare allo stato precedente all'installazione di Squid usare il checkpoint `CH9-PROXY01-PRE-SQUID`.

## Squid

Backup realmente creati:

- `/etc/squid/squid.conf.pkg-default`
- `/etc/squid/squid.conf.r1.1-basic-validated`
- `/etc/squid/squid.conf.r2-disk-cache-validated`
- `/etc/squid/squid.conf.r3-domain-acl-validated`
- `/etc/squid/squid.conf.r4-auth-working`

Per ripristinare una configurazione precedente:

```bash
sudo cp -a /etc/squid/squid.conf.r3-domain-acl-validated /etc/squid/squid.conf
sudo squid -k parse
sudo systemctl restart squid
```

Sostituire il file sorgente con il checkpoint di configurazione desiderato.

## BIND

Backup pre-Capitolo 9:

- `/etc/bind/db.lab.test.pre-ch9-proxy01`
- `/etc/bind/db.10.77.0.pre-ch9-proxy01`

Copie dello stato finale validate:

- `/etc/bind/db.lab.test.CH9-FINAL-VALIDATED`
- `/etc/bind/db.10.77.0.CH9-FINAL-VALIDATED`

Per il rollback DNS, ripristinare le due copie `.pre-ch9-proxy01`, validare con `named-checkzone` e quindi eseguire `rndc reload`.

## Windows NRPT

Il Capitolo 9 ha aggiunto esclusivamente:

- namespace: `.0.77.10.in-addr.arpa`
- DNS server: `10.77.0.10`
- commento: `Linuxshell Press - Capitolo 9`

La regola `.lab.test` del Capitolo 7 e le eventuali regole di altri software non devono essere rimosse.

## Password NCSA

Il laboratorio usa l'utente `proxyuser` e la password didattica `123`. Il file `/etc/squid/passwd` non è incluso nel repository: va rigenerato con `linux/create-lab-user.sh`.
