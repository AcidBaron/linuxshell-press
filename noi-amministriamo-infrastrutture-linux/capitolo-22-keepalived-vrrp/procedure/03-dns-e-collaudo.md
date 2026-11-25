# Failover, failback, passaggio DNS e collaudo finale

## Primo test VRRP con URL via VIP

**Su rp01, Bash**, simulare il guasto:

```bash
sudo systemctl stop nginx
```

**Su proxy01 e rp01 separatamente**:

```bash
ip -4 -br addr show dev eth0
```

È stato osservato proxy01 con 10.77.0.90/24 e rp01 senza VIP.

**Su linux-client01, Bash:**

```bash
curl -I \
    --connect-timeout 3 \
    --max-time 10 \
    --resolve nextcloud.lab.test:443:10.77.0.90 \
    https://nextcloud.lab.test/
```

Risultato: HTTP 302 e redirect al login, serviti dallo standby. Ripristinare il servizio:

```bash
# Su rp01
sudo systemctl start nginx
ip -4 -br addr show dev eth0

# Su proxy01
ip -4 -br addr show dev eth0
```

Dopo la riconvergenza, la VIP torna a rp01. Verifica finale realmente svolta:

```bash
# Su rp01 e proxy01, separatamente
systemctl is-active nginx keepalived
ip -4 -br addr show dev eth0
```

Entrambi i servizi sono active su entrambe le VM; VIP solo su rp01.

## DNS definitivo

**Su infra01, Bash**, backup e aggiornamento mirato del record Nextcloud.

```bash
sudo cp -a \
    /etc/bind/db.lab.test \
    /etc/bind/db.lab.test.pre-ch22-vip

sudo python3 - <<'PY'
from pathlib import Path
from datetime import datetime
import re

path = Path('/etc/bind/db.lab.test')
text = path.read_text()
pattern = (
    r'(?m)^([ \t]*nextcloud[ \t]+IN[ \t]+A[ \t]+)'
    r'10\.77\.0\.50([ \t]*(?:;[^\n]*)?)$'
)
text, count = re.subn(pattern, r'\g<1>10.77.0.90\g<2>', text)
if count != 1:
    raise SystemExit('Record Nextcloud non trovato o ambiguo')
m = re.search(r'(\d{10})([ \t]*;[ \t]*Serial\b)', text, re.I)
if not m:
    raise SystemExit('Serial SOA non trovato')
old = m.group(1)
today = datetime.now().strftime('%Y%m%d')
candidate = today + '01'
new = str(int(old) + 1) if old >= candidate else candidate
text = text[:m.start(1)] + new + text[m.end(1):]
path.write_text(text)
print(f'Serial SOA: {old} -> {new}')
print('Nextcloud: 10.77.0.50 -> 10.77.0.90')
PY

sudo named-checkzone lab.test /etc/bind/db.lab.test
sudo rndc reload lab.test
```

Osservato: 2026112401 → 2026112501; validazione OK; reload queued. Warning noti per deleghe AD e FreeIPA, non causati da questo cambiamento.

**Su linux-client01, Bash:**

```bash
dig @10.77.0.10 nextcloud.lab.test A +short
curl -I --connect-timeout 3 --max-time 10 \
    https://nextcloud.lab.test/
```

Risultato: 10.77.0.90 e HTTP 302.

## Collaudo con DNS normale, senza --resolve

**Su rp01, Bash:**

```bash
sudo systemctl stop nginx
```

**Su linux-client01, Bash:**

```bash
curl -sS -I \
    --connect-timeout 3 \
    --max-time 10 \
    -o /dev/null \
    -w 'HTTP=%{http_code} IP=%{remote_ip}\n' \
    https://nextcloud.lab.test/
```

Output realmente ottenuto:

```text
HTTP=302 IP=10.77.0.90
```

Contemporaneamente la VIP era su proxy01. **Su rp01** ripristinare subito Nginx e leggere eth0:

```bash
sudo systemctl start nginx
ip -4 -br addr show dev eth0
```

Output: 10.77.0.50/24 e 10.77.0.90/24.

Non è stato misurato alcun RTO quantitativo e non è stato dimostrato il mantenimento delle sessioni TCP già aperte.

## Chiusura Hyper-V

**PowerShell amministrativa sul PC Windows:**

```powershell
"rp01","proxy01","web01","infra01" |
    ForEach-Object {
        Checkpoint-VM `
            -Name $_ `
            -SnapshotName "CH22-KEEPALIVED-VRRP-COMPLETE"
    }

Remove-VMSnapshot `
    -VMName "proxy01" `
    -Name "CH22-PRE-HA-STANDBY"
```

Questi comandi risultano eseguiti senza errori. I checkpoint non sono backup coordinati.
