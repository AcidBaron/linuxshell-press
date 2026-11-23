# Capitolo 17 — SSSD, realmd e Kerberos

Materiale operativo del Capitolo 17 di **Noi Amministriamo Infrastrutture Linux**.

Il laboratorio parte dallo stato finale del Capitolo 16: `linux-client01` è già membro del dominio Active Directory `ad.lab.test`, mantiene anche il provider OpenLDAP `lab.test` e usa SSSD per entrambi i domini. Il capitolo non ripete il join: osserva e valida il comportamento reale di realmd, SSSD e Kerberos.

## Stato di partenza

- client: `linux-client01`
- Domain Controller: `dc01.ad.lab.test` — `10.77.0.80`
- realm Kerberos: `AD.LAB.TEST`
- dominio AD: `ad.lab.test`
- provider SSSD esistenti: `lab.test` via LDAP e `ad.lab.test` via AD
- utente AD di laboratorio: `aduser01@ad.lab.test`
- password LAB ONLY usata nelle prove: `123456Aa!`
- checkpoint di partenza: `CH16-AD-LAB-COMPLETE`

## 1. Verificare realmd e SSSD

```bash
realm list

sudo sssctl domain-list

sudo sssctl domain-status ad.lab.test
```

Nel laboratorio `ad.lab.test` risulta configurato come `kerberos-member`; SSSD vede entrambi i domini `lab.test` e `ad.lab.test`; il dominio AD è `Online` e il Domain Controller attivo è `dc01.ad.lab.test`.

La voce `AD Global Catalog: not connected` non ha impedito lookup, autenticazione o Kerberos e non è stata trattata come errore in assenza di un sintomo reale.

## 2. Installare gli strumenti Kerberos

```bash
command -v kinit
command -v klist
```

Se non presenti:

```bash
sudo apt install -y krb5-user
```

Verifica:

```bash
command -v kinit
command -v klist
```

Percorsi validati:

```text
/usr/bin/kinit
/usr/bin/klist
```

## 3. Osservare il keytab della macchina

```bash
sudo klist -k -e /etc/krb5.keytab
```

Nel laboratorio sono presenti principal per:

```text
LINUX-CLIENT01$@AD.LAB.TEST
host/LINUX-CLIENT01@AD.LAB.TEST
RestrictedKrbHost/LINUX-CLIENT01@AD.LAB.TEST
```

con chiavi AES128 e AES256. Alcune entry `arcfour-hmac` risultano `DEPRECATED`, ma le chiavi AES moderne sono presenti e Kerberos funziona correttamente.

## 4. Ottenere un TGT

Prima:

```bash
klist
```

Stato iniziale validato:

```text
No credentials cache found
```

Ottenere il TGT:

```bash
kinit aduser01@AD.LAB.TEST
```

Inserire la password LAB ONLY `123456Aa!`.

Poi:

```bash
klist
```

La cache contiene:

```text
krbtgt/AD.LAB.TEST@AD.LAB.TEST
```

## 5. Richiedere un ticket di servizio

```bash
kvno host/dc01.ad.lab.test
klist
```

Nel laboratorio il ticket di servizio ottenuto è:

```text
host/dc01.ad.lab.test@AD.LAB.TEST
```

con `kvno = 3`.

## 6. Eliminare i ticket senza perdere l'identità SSSD

```bash
kdestroy
klist

id 'aduser01@ad.lab.test'
```

Dopo `kdestroy` non esiste più una credentials cache Kerberos, ma SSSD continua a risolvere correttamente l'identità Active Directory.

## 7. Osservare e invalidare la cache SSSD

```bash
sudo sssctl user-show 'aduser01@ad.lab.test'
```

Invalidare soltanto questa voce:

```bash
sudo sssctl cache-expire \
    -u 'aduser01@ad.lab.test'
```

Verificare:

```bash
sudo sssctl user-show 'aduser01@ad.lab.test'
```

Nel laboratorio la voce mostra:

```text
Cache entry expiration time: Expired
Initgroups expiration time: Expired
```

Forzare un nuovo lookup e osservare il refresh:

```bash
id 'aduser01@ad.lab.test'

sudo sssctl user-show 'aduser01@ad.lab.test'
```

## 8. Validare e leggere la configurazione SSSD

```bash
sudo sssctl config-check
```

Risultato validato:

```text
Issues identified by validators: 0
Messages generated during configuration merging: 0
```

Mostrare soltanto le righe operative:

```bash
sudo grep -vE '^[[:space:]]*($|#)' \
    /etc/sssd/sssd.conf
```

Parametri rilevanti del dominio AD osservati nel laboratorio:

```text
id_provider = ad
cache_credentials = True
krb5_store_password_if_offline = True
krb5_realm = AD.LAB.TEST
fallback_homedir = /home/%u@%d
use_fully_qualified_names = True
ldap_id_mapping = True
access_provider = ad
```

## 9. Leggere la configurazione Kerberos

```bash
grep -vE '^[[:space:]]*($|#)' \
    /etc/krb5.conf
```

Configurazione validata:

```text
[libdefaults]
udp_preference_limit = 0
default_realm = AD.LAB.TEST
```

## 10. Verificare l'autenticazione offline SSSD

Sul PC Windows, PowerShell amministrativa:

```powershell
Stop-VM -Name "dc01"
```

Su `linux-client01`:

```bash
su - 'aduser01@ad.lab.test'
```

Usare la password LAB ONLY `123456Aa!`.

Dopo il login:

```bash
whoami
pwd
```

Risultato validato con il DC spento:

```text
aduser01@ad.lab.test
/home/aduser01@ad.lab.test
```

Riaccendere subito il Domain Controller:

```powershell
Start-VM -Name "dc01"
```

La prova dimostra il funzionamento delle credenziali in cache SSSD senza introdurre modifiche artificiali a firewall o rete.

## 11. Checkpoint finale

Il Capitolo 17 modifica in modo permanente soltanto `linux-client01` con l'installazione di `krb5-user`.

Sul PC Windows:

```powershell
Checkpoint-VM `
    -Name "linux-client01" `
    -SnapshotName "CH17-SSSD-KERBEROS-COMPLETE"
```

`dc01` non richiede un nuovo checkpoint perché durante il capitolo viene soltanto spento e riacceso.

## Regole operative

- Non cancellare manualmente i database sotto `/var/lib/sss` per aggiornare una singola identità: usare `sssctl cache-expire -u`.
- Non confondere l'assenza di ticket in `klist` con un malfunzionamento SSSD.
- Il keytab della macchina e la cache Kerberos dell'utente sono oggetti distinti.
- Le password indicate sono LAB ONLY e non devono essere riutilizzate in produzione.
- Non versionare keytab, chiavi private o altri secret crittografici.
