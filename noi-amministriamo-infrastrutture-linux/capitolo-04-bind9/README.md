# Capitolo 4 – DNS con BIND9

Configurazioni finali validate del Capitolo 4.

## File

- `config/named.conf.options` — ACL, listener, ricorsione e forwarder.
- `config/named.conf.local` — zona diretta e zona inversa.
- `zones/db.lab.test` — zona diretta finale del capitolo.
- `zones/db.10.77.0` — zona inversa finale del capitolo.
- `client/50-cloud-init.yaml` — resolver interno su `linux-client01`.
- `linux/verify-bind.sh` — controlli sintattici e query di verifica.
- `rollback/README.md` — backup creati e ritorno alla configurazione precedente.

### Nota DNSSEC

Nel laboratorio `dnssec-validation no` è un workaround documentato per il percorso upstream che produceva SERVFAIL/broken trust chain. Non è presentato come raccomandazione generale per produzione.
