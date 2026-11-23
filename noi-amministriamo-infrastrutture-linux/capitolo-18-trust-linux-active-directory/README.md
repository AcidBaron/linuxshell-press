# Capitolo 18 — Trust fra domini Linux e Active Directory

Materiale operativo del Capitolo 18 di **Noi Amministriamo Infrastrutture Linux**.

Il laboratorio collega il dominio FreeIPA/IdM `idm.lab.test` al dominio Active Directory `ad.lab.test` con un trust reale. Il risultato finale consente a IdM di risolvere identità AD e di associarle alle proprie policy tramite external group e gruppi POSIX, senza duplicare gli account nella directory IdM.

## Stato validato

- IdM: `ipa01.idm.lab.test` — `10.77.0.70`
- Active Directory: `dc01.ad.lab.test` — `10.77.0.80`
- dominio IdM: `idm.lab.test`
- dominio AD: `ad.lab.test`
- trust: `Established and verified`
- utente AD di verifica: `aduser01@ad.lab.test`
- external group IdM: `ad_users_external`
- gruppo POSIX IdM: `ad_users`
- GID osservato nel laboratorio: `115800006`
- checkpoint finale: `CH18-AD-TRUST-COMPLETE` su `ipa01` e `dc01`

## File operativi

- `powershell/01-add-idm-conditional-forwarder.ps1` — conditional forwarder sul DNS AD.
- `linux/01-prepare-idm-ad-trust.sh` — DNS IdM, DNSSEC, pacchetti trust, ipa-adtrust-install e firewall.
- `linux/02-create-trust-and-map-user.sh` — creazione trust, verifica identità AD e mapping external group → gruppo POSIX.
- `rollback/README.md` — punti di ritorno e rimozione delle modifiche del capitolo.

## 1. Checkpoint pre-trust

Sul PC Windows, PowerShell amministrativa:

```powershell
Checkpoint-VM `
    -Name "ipa01" `
    -SnapshotName "CH18-PRE-AD-TRUST"

Checkpoint-VM `
    -Name "dc01" `
    -SnapshotName "CH18-PRE-AD-TRUST"
```

`linux-client01` non viene modificato.

## 2. DNS: rendere IdM visibile ad Active Directory

Su `dc01`:

```powershell
Add-DnsServerConditionalForwarderZone `
    -Name "idm.lab.test" `
    -MasterServers 10.77.0.70 `
    -ReplicationScope Forest `
    -PassThru

Resolve-DnsName `
    _kerberos._udp.idm.lab.test `
    -Type SRV `
    -Server 127.0.0.1
```

Risultato validato: il servizio Kerberos viene risolto verso `ipa01.idm.lab.test`, IPv4 `10.77.0.70`.

## 3. DNS: rendere Active Directory visibile a IdM

Su `ipa01`:

```bash
kinit admin

ipa dnsforwardzone-add ad.lab.test \
    --forwarder=10.77.0.80 \
    --forward-policy=only
```

Nel laboratorio la zona viene creata ma IdM segnala un problema DNSSEC e il successivo `dig` restituisce `SERVFAIL`.

## 4. Correggere la validazione DNSSEC

Salvare il file:

```bash
sudo cp -a \
    /etc/named/ipa-options-ext.conf \
    /etc/named/ipa-options-ext.conf.pre-ch18-ad-trust
```

Verificare la direttiva esistente:

```bash
sudo grep -n 'dnssec-validation' \
    /etc/named/ipa-options-ext.conf
```

Stato osservato:

```text
18:dnssec-validation yes;
```

Modificare la direttiva già presente:

```bash
sudo sed -i \
    's/^[[:space:]]*dnssec-validation[[:space:]].*;/dnssec-validation no;/' \
    /etc/named/ipa-options-ext.conf

sudo named-checkconf
sudo systemctl restart named
```

Verifica:

```bash
dig @127.0.0.1 \
    _ldap._tcp.dc._msdcs.ad.lab.test SRV \
    +comments +answer
```

Risultato validato: `NOERROR` e SRV `0 100 389 dc01.ad.lab.test.`.

### Troubleshooting — direttiva duplicata

Un primo tentativo con `tee -a` ha prodotto:

```text
'dnssec-validation' redefined near 'dnssec-validation'
```

Il file conteneva già la direttiva. Ripristinare il backup e modificare la riga esistente:

```bash
sudo cp -a \
    /etc/named/ipa-options-ext.conf.pre-ch18-ad-trust \
    /etc/named/ipa-options-ext.conf

sudo named-checkconf
sudo systemctl restart named

sudo grep -n 'dnssec-validation' \
    /etc/named/ipa-options-ext.conf
```

## 5. Preparare ipa01 come AD trust controller

```bash
sudo dnf install -y \
    freeipa-server-trust-ad \
    samba-client

kinit admin

sudo ipa-adtrust-install
```

Nel laboratorio vengono accettati:

- sovrascrittura della configurazione Samba esistente;
- supporto ai domini trusted nel plugin Schema Compatibility.

La procedura termina con `Setup complete`.

## 6. Riavviare IdM e aprire il servizio firewall del trust

```bash
sudo ipactl restart

IFACE=$(ip route show default | awk '/default/ {print $5; exit}')
ZONE=$(sudo firewall-cmd --get-zone-of-interface="$IFACE")

echo "Interfaccia: $IFACE"
echo "Zona firewalld: $ZONE"

sudo firewall-cmd \
    --zone="$ZONE" \
    --permanent \
    --add-service=freeipa-trust

sudo firewall-cmd --reload
```

Stato osservato: interfaccia `eth0`, zona `FedoraServer`, comandi firewall `success`.

## 7. Verificare SMB e le credenziali dell'amministratore AD

```bash
smbclient \
    -L //dc01.ad.lab.test \
    -U 'AD\Administrator'
```

Inserire la password LAB ONLY dell'account `Administrator` del dominio configurata nel Capitolo 16.

Il risultato validato elenca `ADMIN$`, `C$`, `IPC$`, `NETLOGON` e `SYSVOL`.

## 8. Creare il trust

```bash
kinit admin

ipa trust-add \
    --type=ad \
    ad.lab.test \
    --admin Administrator \
    --password \
    --range-type=ipa-ad-trust
```

Inserire la password corretta dell'Administrator AD quando richiesta.

Risultato validato:

```text
Trust direction: Trusting forest
Trust type: Active Directory domain
Trust status: Established and verified
```

### Troubleshooting — logon AD non valido

Il primo `trust-add` ha fallito con:

```text
The attempted logon is invalid
```

DNS e connettività erano già validati. La causa era la password errata dell'account Administrator. Il test `smbclient` verso `dc01` ha permesso di validare la credenziale corretta prima di ripetere il trust.

## 9. Aggiornare i domini trusted e risolvere un utente AD

```bash
ipa trust-fetch-domains ad.lab.test

id 'aduser01@ad.lab.test'
```

Nel laboratorio non vengono trovati domini aggiuntivi; `aduser01@ad.lab.test` viene però risolto correttamente con UID, GID e gruppo `domain users@ad.lab.test`.

## 10. Mappare un utente AD nelle policy IdM

Creare l'external group:

```bash
ipa group-add \
    --desc='Utenti AD - mapping esterno' \
    ad_users_external \
    --external
```

Creare il gruppo POSIX IdM:

```bash
ipa group-add \
    --desc='Utenti AD autorizzati in IdM' \
    ad_users
```

Aggiungere l'utente trusted:

```bash
ipa group-add-member \
    ad_users_external \
    --external 'aduser01@ad.lab.test'
```

Lasciare vuote le richieste interattive per member user/group/service/User ID override. FreeIPA registra il SID AD come external member.

Annidare l'external group nel gruppo POSIX:

```bash
ipa group-add-member \
    ad_users \
    --groups ad_users_external
```

Aggiornare soltanto la voce SSSD interessata:

```bash
sudo sssctl cache-expire \
    -u 'aduser01@ad.lab.test'

id 'aduser01@ad.lab.test'
```

Risultato validato: compare anche `115800006(ad_users)`.

## 11. Stato finale e checkpoint

```powershell
Checkpoint-VM `
    -Name "ipa01" `
    -SnapshotName "CH18-AD-TRUST-COMPLETE"

Checkpoint-VM `
    -Name "dc01" `
    -SnapshotName "CH18-AD-TRUST-COMPLETE"

Remove-VMSnapshot `
    -VMName "ipa01" `
    -Name "CH18-PRE-AD-TRUST"

Remove-VMSnapshot `
    -VMName "dc01" `
    -Name "CH18-PRE-AD-TRUST"
```

## Credenziali e secret

Le password dichiaratamente didattiche sono LAB ONLY e possono essere riportate quando servono alla replicabilità.

Non versionare keytab, chiavi private, token, secret crittografici o credenziali reali.
