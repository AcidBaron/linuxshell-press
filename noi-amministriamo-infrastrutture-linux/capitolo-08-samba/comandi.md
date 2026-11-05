# Capitolo 8 – Samba: condivisione file Linux e Windows — comandi e configurazioni
> Estratto operativo dal master `Capitolo_08_Samba_COMPLETO_DNR.docx`. I blocchi sono riportati nell'ordine del capitolo.

## 8.1.1 Creazione della VM

```powershell
.\\New-LabLinuxVM-R2_2.ps1 `
    -Name "files01" `
    -IPAddress "10.77.0.20" `
    -Prefix 24 `
    -Gateway "10.77.0.1" `
    -DNS1 "10.77.0.10" `
    -SearchDomain "lab.test" `
    -FinalSwitch "LAB-LAN" `
    -NonInteractive
```

## 8.1.2 Verifica della rete prima del DNS

```bash
hostnamectl --static
hostname -f
ip -br addr
ip route
resolvectl status
ping -c 3 10.77.0.1
ping -c 3 10.77.0.10
ping -c 3 1.1.1.1
```

## 8.1.3 Registrazione di files01 in BIND

```bash
sudo cp -a /etc/bind/db.lab.test \
    /etc/bind/db.lab.test.pre-ch8-files01

sudo cp -a /etc/bind/db.10.77.0 \
    /etc/bind/db.10.77.0.pre-ch8-files01
```

```bash
sudo python3 - <<'PY'
from pathlib import Path
from datetime import datetime, timezone
import re

def bump_serial(text):
    today = datetime.now(timezone.utc).strftime("%Y%m%d")
    m = re.search(r'(\d{10})(\s*;\s*serial)', text)
    if not m:
        raise SystemExit("ERRORE: seriale SOA non trovato")
    old = m.group(1)
    if old.startswith(today):
        n = int(old[-2:]) + 1
        if n > 99:
            raise SystemExit("ERRORE: contatore seriale giornaliero esaurito")
        new = f"{today}{n:02d}"
    else:
        new = f"{today}01"
    return text[:m.start(1)] + new + text[m.end(1):], old, new
```

```bash
# Forward zone
p = Path("/etc/bind/db.lab.test")
s = p.read_text()
if re.search(r'^\s*files01\s+', s, re.M):
    raise SystemExit("ERRORE: files01 esiste già nella zona forward")
marker = "dns             IN  CNAME   infra01.lab.test.\n"
if marker not in s:
    raise SystemExit("ERRORE: punto di inserimento forward non trovato")
s = s.replace(marker, "files01         IN  A       10.77.0.20\n\n" + marker, 1)
s, oldf, newf = bump_serial(s)
p.write_text(s)
```

```bash
# Reverse zone
p = Path("/etc/bind/db.10.77.0")
s = p.read_text()
if re.search(r'^\s*20\s+IN\s+PTR\s+', s, re.M):
    raise SystemExit("ERRORE: PTR .20 esiste già")
marker = "101     IN  PTR linux-client01.lab.test.\n"
if marker not in s:
    raise SystemExit("ERRORE: punto di inserimento reverse non trovato")
s = s.replace(marker, "20      IN  PTR files01.lab.test.\n" + marker, 1)
s, oldr, newr = bump_serial(s)
p.write_text(s)
print(f"Forward serial: {oldf} -> {newf}")
print(f"Reverse serial: {oldr} -> {newr}")
PY
```

```bash
echo "=== CH8 BIND FILES01 CHECK ==="
sudo named-checkzone lab.test /etc/bind/db.lab.test
echo "forward_exit=$?"
sudo named-checkzone 0.77.10.in-addr.arpa /etc/bind/db.10.77.0
echo "reverse_exit=$?"
sudo named-checkconf
echo "conf_exit=$?"
grep -n 'files01' /etc/bind/db.lab.test /etc/bind/db.10.77.0
```

```bash
sudo systemctl reload bind9
systemctl is-active bind9

dig @10.77.0.10 files01.lab.test A +short
dig @10.77.0.10 -x 10.77.0.20 +short
```

## 8.1.4 Verifica DNS da files01 e da Windows

```bash
getent ahostsv4 files01.lab.test
host files01.lab.test 10.77.0.10
host 10.77.0.20 10.77.0.10
hostname -f
```

```powershell
Resolve-DnsName files01.lab.test -DnsOnly
Resolve-DnsName 10.77.0.20 -Server 10.77.0.10 -DnsOnly
ping files01.lab.test
```

## 8.2.1 Ubuntu/Debian: preflight e installazione

```bash
echo "=== CH8 SAMBA PRE-INSTALL ==="
apt-cache policy samba smbclient
systemctl status smbd nmbd --no-pager 2>/dev/null || true
sudo ss -lntup | grep -E '(:137|:138|:139|:445)\b' || true
```

```bash
sudo apt update
sudo apt install -y samba smbclient
smbd --version
```

## 8.2.2 SMB diretto su TCP/445 e NetBIOS legacy

```bash
sudo systemctl enable --now smbd
sudo systemctl disable --now nmbd
systemctl is-enabled smbd
systemctl is-active smbd
systemctl is-enabled nmbd
systemctl is-active nmbd
sudo ss -lntup | grep -E '(:137|:138|:139|:445)\b'
```

## 8.2.3 Differenze Fedora/RHEL

```bash
sudo dnf install -y samba samba-client cifs-utils
sudo systemctl enable --now smb
sudo firewall-cmd --permanent --add-service=samba
sudo firewall-cmd --reload
```

## 8.3 Utenti Linux, database Samba e directory condivisa

```bash
sudo groupadd --system smbusers
sudo useradd --system --no-create-home --shell /usr/sbin/nologin -g smbusers smbuser
sudo smbpasswd -a smbuser
getent group smbusers
id smbuser
sudo pdbedit -L -v smbuser
```

```bash
sudo install -d -o root -g smbusers -m 2770 /srv/samba/dati
ls -ld /srv/samba/dati
```

## 8.4 Una configurazione minima e leggibile

```bash
sudo cp -a /etc/samba/smb.conf /etc/samba/smb.conf.pre-ch8
```

```ini
[global]
    workgroup = WORKGROUP
    server role = standalone server
    server string = files01 Samba file server

    interfaces = lo eth0
    bind interfaces only = yes
    smb ports = 445
    server min protocol = SMB2_02

    map to guest = Never
    usershare allow guests = no

    load printers = no
    disable spoolss = yes
    printcap name = /dev/null

    log file = /var/log/samba/log.%m
    max log size = 1000
    logging = file

[dati]
    path = /srv/samba/dati
    browseable = yes
    read only = no
    guest ok = no
    valid users = @smbusers
    force group = smbusers
    create mask = 0660
    directory mask = 2770
```

```bash
sudo testparm -s
echo "testparm_exit=$?"
sudo systemctl restart smbd
systemctl is-active smbd
sudo ss -lntp | grep ':445'
```

## 8.5 Accesso da Windows

```powershell
Test-NetConnection files01.lab.test -Port 445
net use Z: \\files01.lab.test\dati /user:smbuser * /persistent:no
Get-SmbMapping
Get-ChildItem Z:\
```

## 8.6 Accesso da Linux: smbclient e mount CIFS

```bash
sudo apt update
sudo apt install -y smbclient cifs-utils
smbclient -L //files01.lab.test -U smbuser
smbclient //files01.lab.test/dati -U smbuser -c 'ls'
```

```bash
sudo install -m 600 /dev/null /root/.ch8-smb-credentials
# contenuto: username=smbuser e password inserita in modo protetto
sudo mkdir -p /mnt/files01-dati
sudo mount -t cifs //files01.lab.test/dati /mnt/files01-dati \
  -o credentials=/root/.ch8-smb-credentials,vers=3.1.1,uid=$(id -u),gid=$(id -g),file_mode=0660,dir_mode=0770
```

## 8.7.2 Rendere obbligatoria la firma

```bash
sudo cp -a /etc/samba/smb.conf /etc/samba/smb.conf.pre-ch8-signing
```

```bash
sudo python3 - <<'PY'
from pathlib import Path
p = Path('/etc/samba/smb.conf')
s = p.read_text()
needle = '    server min protocol = SMB2_02\n'
if 'server signing' not in s:
    s = s.replace(needle, needle + '    server signing = mandatory\n', 1)
p.write_text(s)
PY

sudo testparm -s
echo "testparm_exit=$?"
sudo systemctl restart smbd
systemctl is-active smbd
```

```powershell
net use Z: /delete /y
net use Z: \\files01.lab.test\dati /user:smbuser * /persistent:no
Get-SmbConnection |
  Where-Object ServerName -eq "files01.lab.test" |
  Format-List ServerName,ShareName,Credential,Dialect,Signed,Encrypted
```

```bash
sudo smbstatus
```

## 8.8 Permessi: reader, writer e gruppi

```bash
sudo useradd --system --no-create-home --shell /usr/sbin/nologin -g smbusers smbread
sudo smbpasswd -a smbread
getent passwd smbread
id smbread
sudo pdbedit -L smbread
```

## 8.8.1 Trasformare la share in read-only con eccezione di scrittura

```bash
sudo cp -a /etc/samba/smb.conf /etc/samba/smb.conf.pre-ch8-readwrite
```

```bash
sudo python3 - <<'PY'
from pathlib import Path
p = Path('/etc/samba/smb.conf')
s = p.read_text()
old = "    read only = no\n    guest ok = no\n    valid users = @smbusers\n"
new = "    read only = yes\n    guest ok = no\n    valid users = @smbusers\n    write list = smbuser\n"
if old not in s:
    raise SystemExit('ERRORE: blocco share atteso non trovato')
p.write_text(s.replace(old, new, 1))
PY

sudo testparm -s
echo "testparm_exit=$?"
sudo systemctl restart smbd
systemctl is-active smbd
```

## 8.9.1 Preflight: il servizio era raggiungibile senza firewall host

```bash
echo "=== CH8 UFW PREFLIGHT ==="
sudo ufw status verbose || true
sudo ss -lntp | grep ':22' || true
sudo ss -lntp | grep ':445' || true
```

## 8.9.2 Policy UFW per la LAB-LAN

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow from 10.77.0.0/24 to any port 22 proto tcp
sudo ufw allow from 10.77.0.0/24 to any port 445 proto tcp
sudo ufw allow from fd3a:7b4c:2d91:1::/64 to any port 22 proto tcp
sudo ufw allow from fd3a:7b4c:2d91:1::/64 to any port 445 proto tcp
sudo ufw --force enable
sudo ufw status numbered
sudo ufw status verbose
```

## 8.9.3 Verifica dal client autorizzato

```powershell
Test-NetConnection files01.lab.test -Port 445
Test-NetConnection files01.lab.test -Port 22
```

## 8.10 Persistenza e test post-reboot

```bash
systemctl is-enabled smbd
systemctl is-active smbd
systemctl is-enabled nmbd
systemctl is-active nmbd
sudo testparm -s >/dev/null && echo testparm_exit=0
sudo ss -lntp | grep ':445'
sudo ufw status verbose
```

```bash
ping -c 3 10.77.0.20
smbclient -L //10.77.0.20 -U smbuser
smbclient //10.77.0.20/dati -U smbuser -c 'ls'
```

## 8.11.3 Terzo e ultimo test: isolare la race

```ini
[Unit]
Description=Wait for stable IPv6 ULA on eth0 before Samba
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'for i in {1..60}; do ip -6 -o addr show dev eth0 scope global | grep -v tentative | grep -q "fd3a:7b4c:2d91:1:" && exit 0; sleep 1; done; exit 1'
RemainAfterExit=yes
```

```ini
[Unit]
Requires=smbd-ipv6-ready.service
After=smbd-ipv6-ready.service
```

## A.2 Configurazione finale validata

```ini
[global]
    bind interfaces only = Yes
    interfaces = lo eth0
    disable spoolss = Yes
    load printers = No
    printcap name = /dev/null
    server role = standalone server
    server signing = required
    server string = files01 Samba file server
    smb ports = 445

[dati]
    create mask = 0660
    directory mask = 02770
    force group = smbusers
    path = /srv/samba/dati
    valid users = @smbusers
    write list = smbuser
```

## A.3 Rollback DNS BIND

```bash
sudo cp -a /etc/bind/db.lab.test.pre-ch8-files01 /etc/bind/db.lab.test
sudo cp -a /etc/bind/db.10.77.0.pre-ch8-files01 /etc/bind/db.10.77.0
sudo named-checkzone lab.test /etc/bind/db.lab.test
sudo named-checkzone 0.77.10.in-addr.arpa /etc/bind/db.10.77.0
sudo named-checkconf
sudo systemctl reload bind9
```

## A.4 Rollback Samba

```bash
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.before-rollback
sudo cp /etc/samba/smb.conf.pre-ch8 /etc/samba/smb.conf
sudo testparm -s
sudo systemctl restart smbd
```
