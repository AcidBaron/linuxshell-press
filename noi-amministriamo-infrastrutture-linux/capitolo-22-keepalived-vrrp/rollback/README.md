# Rollback del Capitolo 22

## Stato e punti di ritorno

- Checkpoint finali **CH22-KEEPALIVED-VRRP-COMPLETE** su rp01, proxy01, web01, infra01.
- Checkpoint temporaneo **CH22-PRE-HA-STANDBY** su proxy01 eliminato dopo il collaudo.
- Backup DNS su infra01: \`/etc/bind/db.lab.test.pre-ch22-vip\`.
- Eventuali backup Keepalived: \`/etc/keepalived/keepalived.conf.pre-ch22\`.
- I certificati/chiavi TLS privati restano sui nodi e non si pubblicano nel repository.

## Ripristino d'emergenza senza VIP

**Su rp01 e proxy01**, Bash:

```bash
sudo systemctl stop keepalived
```

La VIP viene rilasciata e il nome DNS, finché punta a 10.77.0.90, potrebbe non funzionare. L'accesso d'emergenza può usare l'IP permanente rp01 con un override locale del nome TLS fino al ripristino di BIND.

## DNS precedente

**Su infra01, Bash**, il seguente rollback **non è stato eseguito nel collaudo**. Ripristina il contenuto della zona dal backup e imposta un seriale più alto dell'attuale, per permettere la propagazione verso eventuali secondari:

```bash
sudo python3 - <<'PY'
from pathlib import Path
import re

live = Path('/etc/bind/db.lab.test')
backup = Path('/etc/bind/db.lab.test.pre-ch22-vip')
current = live.read_text()
restored = backup.read_text()
pattern = r'(\d{10})([ \t]*;[ \t]*Serial\b)'
a = re.search(pattern, current, re.I)
b = re.search(pattern, restored, re.I)
if not a or not b:
    raise SystemExit('Serial SOA non trovato')
serial = str(max(int(a.group(1)), int(b.group(1))) + 1)
restored = restored[:b.start(1)] + serial + restored[b.end(1):]
live.write_text(restored)
print('Seriale di rollback:', serial)
PY

sudo named-checkzone lab.test /etc/bind/db.lab.test
sudo rndc reload lab.test
```

Senza VIP, il backup DNS pre-CH22 riporta nextcloud.lab.test a 10.77.0.50.

## Interventi ulteriori

Nginx standby e la regola UFW proxy01→web01:80 non devono essere eliminati per un semplice rollback DNS. Per un ritorno completo allo stato precedente, ricostruire in sequenza il differenziale sulle quattro VM, controllando che i servizi Squid, Nginx e Nextcloud già validati rimangano operativi. Il ripristino puntuale da checkpoint è un'operazione di laboratorio con effetti sullo stato di quelle VM; valutare prima eventuali dati creati dopo la sua acquisizione.
