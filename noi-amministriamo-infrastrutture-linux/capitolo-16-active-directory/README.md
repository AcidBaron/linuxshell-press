# Capitolo 16 — Active Directory e integrazione Linux

Materiale operativo del Capitolo 16 di **Noi Amministriamo Infrastrutture Linux**.

Il laboratorio è stato completato e validato il **20 novembre 2026**. La catena finale comprende il primo Domain Controller Windows Server 2025, DNS Active Directory per `ad.lab.test`, integrazione con il DNS parent BIND su `infra01` e join di `linux-client01` tramite `realmd`, `adcli` e SSSD.

## Perimetro validato

- Domain Controller: `dc01.ad.lab.test`
- Dominio DNS: `ad.lab.test`
- Nome NetBIOS: `AD`
- Sistema: Windows Server 2025 Standard Evaluation, Server Core
- Livello funzionale: `Windows2025Domain`
- IPv4 di `dc01`: `10.77.0.80/24`
- Gateway: `10.77.0.1`
- DNS AD: integrato su `dc01`
- DNS parent: `infra01` — `10.77.0.10`, BIND autorevole per `lab.test`
- Client Linux: `linux-client01`
- Join Linux: `realmd` + `adcli` + SSSD
- Provider SSSD mantenuti in parallelo: OpenLDAP `lab.test` + Active Directory `ad.lab.test`
- Utente AD di prova: `aduser01@ad.lab.test`
- Home automatica al primo login: validata
- Checkpoint finale: `CH16-AD-LAB-COMPLETE` su `dc01` e `linux-client01`

## File operativi

- `powershell/01-create-dc01-vm.ps1` — creazione VM Hyper-V.
- `powershell/02-configure-dc01-base.ps1` — hostname, rete, DNS iniziale, timezone e OpenSSH.
- `powershell/03-authorize-admin-ssh-key.ps1` — installazione della sola chiave pubblica Ed25519 per Administrator.
- `powershell/04-install-promote-ad.ps1` — installazione AD DS e promozione a prima foresta `ad.lab.test`.
- `powershell/05-fix-openssh-domain-firewall.ps1` — adeguamento della regola OpenSSH dopo il passaggio a `DomainAuthenticated`.
- `config/infra01-bind-ch16-snippets.conf` — record A/PTR, delega e forward zone da integrare nei file BIND esistenti.
- `linux/01-join-ad.sh` — pacchetti, discovery, join, verifica SSSD e `pam_mkhomedir`.
- `rollback/README.md` — rollback dei tre componenti principali.

## 1. Preparazione di dc01

La prima parte del capitolo installa Windows Server 2025 Server Core e prepara `dc01` come server standalone con:

- 2 vCPU;
- RAM dinamica 2–8 GB, startup 4 GB;
- VHDX dinamico da 40 GB;
- switch `LAB-LAN`;
- IPv4 `10.77.0.80/24`;
- DNS iniziale `10.77.0.10` (`infra01`);
- timezone `W. Europe Standard Time`;
- OpenSSH con PowerShell;
- accesso con password e chiave Ed25519.

La chiave privata SSH resta esclusivamente sul PC amministrativo e non viene versionata.

## 2. Preparare il DNS parent prima della promozione

Su `infra01` salvare le zone interessate:

```bash
sudo cp -a /etc/bind/db.lab.test /etc/bind/db.lab.test.pre-ch16-ad
sudo cp -a /etc/bind/db.10.77.0 /etc/bind/db.10.77.0.pre-ch16-ad
```

Aggiungere i record A e PTR con gli stessi comandi usati nel laboratorio:

```bash
sudo tee -a /etc/bind/db.lab.test >/dev/null <<'EOF'
; Capitolo 16 - Active Directory
dc01.ad         IN A        10.77.0.80
EOF

sudo tee -a /etc/bind/db.10.77.0 >/dev/null <<'EOF'
; Capitolo 16 - Active Directory
80              IN PTR      dc01.ad.lab.test.
EOF
```

Incrementare i seriali SOA delle due zone:

```bash
sudo python3 - <<'PY'
from pathlib import Path
import re
from datetime import datetime

paths = [
    Path("/etc/bind/db.lab.test"),
    Path("/etc/bind/db.10.77.0"),
]

today = datetime.now().strftime("%Y%m%d")

for path in paths:
    text = path.read_text()
    m = re.search(r'(\d{10})(\s*;\s*Serial\b)', text, re.I)
    if not m:
        raise SystemExit(f"Serial SOA non trovato in {path}")

    old = m.group(1)
    if old.startswith(today):
        new = str(int(old) + 1)
    else:
        new = today + "01"

    text = text[:m.start(1)] + new + text[m.end(1):]
    path.write_text(text)
    print(f"{path}: {old} -> {new}")
PY
```

Validare e ricaricare:

```bash
sudo named-checkzone lab.test /etc/bind/db.lab.test
sudo named-checkzone 0.77.10.in-addr.arpa /etc/bind/db.10.77.0
sudo rndc reload
```

Prima della promozione è stato creato il checkpoint temporaneo:

```powershell
Checkpoint-VM `
    -Name "dc01" `
    -SnapshotName "CH16-PRE-ADDS-PROMOTION"
```

## 3. Installare AD DS e promuovere dc01

Eseguire su `dc01`:

`powershell/04-install-promote-ad.ps1`

La promozione crea foresta `ad.lab.test`, nome NetBIOS `AD`, DNS integrato, primo Domain Controller e Global Catalog.

`-CreateDnsDelegation:$false` è intenzionale: il parent `lab.test` è gestito da BIND e viene configurato manualmente dopo la validazione del DNS Windows.

La password DSRM usata nel laboratorio è `123456Aa!` ed è **LAB ONLY**.

## 4. Troubleshooting — SSH non raggiungibile dopo la promozione

Dopo il riavvio la rete passa da `Private` a `DomainAuthenticated`. La regola OpenSSH iniziale era limitata a `Private`, quindi TCP/22 può andare in timeout anche con `sshd` in esecuzione.

Usare PowerShell Direct e poi:

`powershell/05-fix-openssh-domain-firewall.ps1`

La regola finale è valida per `Domain,Private`. L'accesso `ssh dc01` con la chiave Ed25519 già configurata torna operativo senza rigenerare le chiavi.

## 5. Verificare dominio e DNS Active Directory

Su `dc01`:

```powershell
Get-ADDomain |
    Select-Object DNSRoot,NetBIOSName,DomainMode

Resolve-DnsName `
    _ldap._tcp.dc._msdcs.ad.lab.test `
    -Type SRV `
    -Server 127.0.0.1

Resolve-DnsName `
    _kerberos._tcp.ad.lab.test `
    -Type SRV `
    -Server 127.0.0.1
```

Stato validato: `ad.lab.test`, NetBIOS `AD`, `Windows2025Domain`; LDAP SRV sulla porta 389 e Kerberos SRV sulla porta 88 verso `dc01.ad.lab.test`.

## 6. Integrare il sottodominio AD con BIND

Prima delle modifiche definitive:

```bash
sudo cp -a /etc/bind/db.lab.test /etc/bind/db.lab.test.pre-ch16-ad-delegation
sudo cp -a /etc/bind/named.conf.local /etc/bind/named.conf.local.pre-ch16-ad
```

Aggiungere la delega NS:

```bash
sudo tee -a /etc/bind/db.lab.test >/dev/null <<'EOF'

; Capitolo 16 - delega DNS Active Directory
ad              IN NS       dc01.ad.lab.test.
EOF
```

Aggiungere la forward zone specifica:

```bash
sudo tee -a /etc/bind/named.conf.local >/dev/null <<'EOF'

zone "ad.lab.test" {
    type forward;
    forward only;
    forwarders {
        10.77.0.80;
    };
};
EOF
```

Incrementare il seriale della sola zona `lab.test`:

```bash
sudo python3 - <<'PY'
from pathlib import Path
import re
from datetime import datetime

path = Path("/etc/bind/db.lab.test")
text = path.read_text()

m = re.search(r'(\d{10})(\s*;\s*Serial\b)', text, re.I)
if not m:
    raise SystemExit("Serial SOA non trovato")

old = m.group(1)
today = datetime.now().strftime("%Y%m%d")

if old.startswith(today):
    new = str(int(old) + 1)
else:
    new = today + "01"

text = text[:m.start(1)] + new + text[m.end(1):]
path.write_text(text)

print(f"{old} -> {new}")
PY
```

Validare, rileggere la configurazione e pulire la cache negativa:

```bash
sudo named-checkzone lab.test /etc/bind/db.lab.test
sudo named-checkconf
sudo rndc reconfig
sudo rndc reload lab.test
sudo rndc flushtree ad.lab.test
```

Test funzionale:

```bash
dig @127.0.0.1     _ldap._tcp.dc._msdcs.ad.lab.test SRV     +comments +answer
```

Risultato validato: `NOERROR` con SRV `0 100 389 dc01.ad.lab.test.`.

### Troubleshooting — BIND restituisce ancora NXDOMAIN

Nel laboratorio il file `db.lab.test` era già al seriale `2026112002`, ma BIND continuava a servire la copia runtime con seriale `2026112001`. Un `dig` diretto a `10.77.0.80` restituiva il record corretto, quindi il DNS Windows era sano.

La correzione è stata:

```bash
sudo rndc reconfig
sudo rndc reload lab.test
sudo rndc flushtree ad.lab.test
```

## 7. Preparare linux-client01

Per il laboratorio AD è stato ripristinato `CH15-PRE-FREEIPA-ENROLLMENT`, che mantiene la configurazione OpenLDAP/SSSD del Capitolo 14 ma precede l'enrollment FreeIPA. `CH15-FREEIPA-LAB-COMPLETE` viene conservato.

```powershell
Stop-VM -Name "linux-client01"

Restore-VMSnapshot `
    -VMName "linux-client01" `
    -Name "CH15-PRE-FREEIPA-ENROLLMENT" `
    -Confirm:$false

Start-VM -Name "linux-client01"
```

La baseline validata conserva `[domain/lab.test]`, `id_provider = ldap` e `ldap_uri = ldap://ldap01.lab.test`, con `ldapuser01` ancora risolvibile.

## 8. Discovery e join Linux

La procedura validata è raccolta in `linux/01-join-ad.sh`.

```bash
sudo realm -v discover ad.lab.test
sudo realm join -v -U Administrator ad.lab.test
```

Il join termina con:

```text
Successfully enrolled machine in realm
```

I messaggi `Encryption type [3] not permitted` e `Encryption type [1] not permitted` sono risultati non bloccanti: riguardano tipi Kerberos legacy e l'enrollment termina correttamente.

## 9. Convivenza OpenLDAP + Active Directory in SSSD

Stato finale:

```text
[sssd]
domains = lab.test, ad.lab.test

[domain/lab.test]
id_provider = ldap
ldap_uri = ldap://ldap01.lab.test

[domain/ad.lab.test]
id_provider = ad
ad_domain = ad.lab.test
krb5_realm = AD.LAB.TEST
```

Verifiche validate:

```bash
getent passwd ldapuser01
id 'Administrator@ad.lab.test'
```

Entrambi i provider rispondono correttamente.

## 10. Utente AD di prova e login Linux

Su `dc01` è stato creato `aduser01` con password didattica **LAB ONLY** `123456Aa!`.

```powershell
$password = ConvertTo-SecureString `
    "123456Aa!" `
    -AsPlainText `
    -Force

New-ADUser `
    -Name "AD User 01" `
    -SamAccountName "aduser01" `
    -UserPrincipalName "aduser01@ad.lab.test" `
    -AccountPassword $password `
    -Enabled $true `
    -ChangePasswordAtLogon $false
```

Sul client:

```bash
id 'aduser01@ad.lab.test'
sudo pam-auth-update --enable mkhomedir
sudo systemctl restart sssd
su - 'aduser01@ad.lab.test'
```

Al primo login viene creata `/home/aduser01@ad.lab.test`.

## 11. Stato finale e checkpoint

```powershell
Checkpoint-VM `
    -Name "dc01" `
    -SnapshotName "CH16-AD-LAB-COMPLETE"

Checkpoint-VM `
    -Name "linux-client01" `
    -SnapshotName "CH16-AD-LAB-COMPLETE"

Remove-VMSnapshot `
    -VMName "dc01" `
    -Name "CH16-PRE-ADDS-PROMOTION"
```

`linux-client01` resta nello stato finale **AD + OpenLDAP**. I checkpoint del Capitolo 15 vengono mantenuti.

## Credenziali e segreti

Le password dichiaratamente didattiche possono essere pubblicate e devono essere marcate **LAB ONLY** quando utili alla replicabilità.

Restano esclusi dal repository: chiavi private SSH, chiavi private di certificati, token, secret crittografici, credenziali reali, file personali `known_hosts` e checkpoint binari.

Le credenziali LAB ONLY non devono essere riutilizzate in produzione.
