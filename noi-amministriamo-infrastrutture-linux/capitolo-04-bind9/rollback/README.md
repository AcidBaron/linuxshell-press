# Rollback – Capitolo 4

Backup creati durante il laboratorio:

- `/etc/bind/named.conf.options.pre-lab`
- `/etc/bind/named.conf.options.pre-dnssec-workaround`
- `/etc/bind/named.conf.local.pre-lab-zones`
- `/etc/bind/db.lab.test.pre-dns-alias`
- `/etc/netplan/50-cloud-init.yaml.pre-infra01-dns`

Ripristinare il file appropriato, validare con `named-checkconf` / `named-checkzone` e ricaricare BIND. Prima di sostituire Netplan sul client usare `netplan generate` e mantenere un canale console di emergenza.
