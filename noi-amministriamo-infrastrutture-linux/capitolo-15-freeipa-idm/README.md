# Capitolo 15 — FreeIPA e Identity Management: identità, Kerberos e policy integrate

Materiale operativo del Capitolo 15 di **Noi Amministriamo Infrastrutture Linux**.

Il laboratorio costruisce un dominio FreeIPA reale su Fedora Server 45, integra DNS, Directory Server, Kerberos e CA, crea identità e gruppi centralizzati, registra un client Ubuntu tramite SSSD e applica una policy sudo granulare.

Verifica tecnologica e laboratorio: **18 novembre 2026**.

## Perimetro

- Server FreeIPA: `ipa01.idm.lab.test` — `10.77.0.70/24`
- Dominio DNS IdM: `idm.lab.test`
- Realm Kerberos: `IDM.LAB.TEST`
- Base DN: `dc=idm,dc=lab,dc=test`
- DNS parent: `infra01.lab.test` — `10.77.0.10`
- DNS integrato FreeIPA autorevole per: `idm.lab.test`
- Forwarder FreeIPA: `10.77.0.10`
- Client: `linux-client01.lab.test` — Ubuntu 24.04
- Utente IdM: `ipauser01`
- Gruppo IdM: `labadmins`
- Regola sudo: `labadmins-whoami`
- Server FreeIPA validato: FreeIPA 4.13.4 su Fedora Server 45
- Client validato: freeipa-client 4.11.1 su Ubuntu 24.04

Password didattiche LAB:

- amministratore FreeIPA e Directory Manager: `12345678`;
- password temporanea iniziale di `ipauser01`: `12345678`;
- password di `ipauser01` dopo il cambio obbligatorio: `123456789`.

> **LAB ONLY:** queste credenziali sono dichiarate intenzionalmente per rendere il laboratorio riproducibile. Non sono adatte alla produzione.

## Prerequisiti

Devono già esistere:

- `fw01` — `10.77.0.1/24`, gateway della LAB-LAN;
- `infra01` — `10.77.0.10/24`, BIND autorevole per `lab.test` e `0.77.10.in-addr.arpa`;
- `linux-client01` — client Ubuntu già usato nel Capitolo 14;
- VM `ipa01` con Fedora Server 45, hostname `ipa01.idm.lab.test`, IP `10.77.0.70/24`, gateway `10.77.0.1`, DNS `10.77.0.10`;
- sincronizzazione temporale funzionante.

Per Fedora Server usare la **DVD ISO**, non la Network Install ISO:

`Fedora-Server-dvd-x86_64-45-1.4.iso`

Nel laboratorio la DVD ISO ha evitato di introdurre una dipendenza dai repository online durante l'installazione del sistema operativo.

## 1. Registrare ipa01 nel DNS parent

I record da aggiungere sono raccolti in:

`dns/parent-records.txt`

Prima dell'installazione FreeIPA devono esistere il record A e il PTR di `ipa01`. Dopo l'installazione del DNS integrato FreeIPA si aggiunge anche la delega NS di `idm.lab.test`.

Validare e ricaricare BIND:

```bash
sudo named-checkzone lab.test /etc/bind/db.lab.test
sudo named-checkzone 0.77.10.in-addr.arpa /etc/bind/db.10.77.0
sudo rndc reload
```

## 2. Installare FreeIPA sul server

**Macchina:** `ipa01`  
**Shell:** Bash/Linux

```bash
sudo dnf install -y \
    freeipa-server \
    freeipa-server-dns

sudo firewall-cmd --permanent --add-service=freeipa-4
sudo firewall-cmd --permanent --add-service=dns
sudo firewall-cmd --reload
sudo firewall-cmd --list-services
```

Prima della configurazione è raccomandato il checkpoint Hyper-V:

```powershell
Checkpoint-VM `
    -Name "ipa01" `
    -SnapshotName "CH15-PRE-FREEIPA-CONFIG"
```

Lo script validato è:

`server/ipa-server-install.sh`

Eseguirlo da `ipa01`:

```bash
sudo bash server/ipa-server-install.sh
```

La configurazione usa:

- hostname `ipa01.idm.lab.test`;
- IP `10.77.0.70`;
- dominio `idm.lab.test`;
- realm `IDM.LAB.TEST`;
- CA integrata FreeIPA/Dogtag;
- DNS integrato;
- forwarder `10.77.0.10`;
- nessuna reverse zone gestita da FreeIPA;
- nessuna riconfigurazione NTP.

Risultato validato:

```text
Setup complete
The ipa-server-install command was successful
```

## 3. Delegazione DNS e forward zone su infra01

Dopo che FreeIPA DNS è attivo, nel parent `lab.test` deve esistere:

```text
idm             IN NS       ipa01.idm.lab.test.
```

Il record A `ipa01.idm IN A 10.77.0.70` resta nel parent come glue.

Nel laboratorio `infra01` usa globalmente:

```text
forward only;
```

Per questo è necessaria anche una forward zone specifica per `idm.lab.test` verso il DNS FreeIPA. Il frammento validato è:

`dns/named.conf.local-idm-forward.conf`

Aggiungerlo a `/etc/bind/named.conf.local`, quindi:

```bash
sudo named-checkconf
sudo rndc reconfig
sudo rndc flushtree idm.lab.test
```

Verifica:

```bash
dig @10.77.0.10 ipa01.idm.lab.test A +noall +answer

dig @10.77.0.10 \
    _ldap._tcp.idm.lab.test SRV \
    +noall +answer

dig @10.77.0.10 \
    _kerberos._udp.idm.lab.test SRV \
    +noall +answer
```

Risultati attesi:

- `ipa01.idm.lab.test -> 10.77.0.70`;
- LDAP SRV -> porta 389 su `ipa01.idm.lab.test`;
- Kerberos SRV -> porta 88 su `ipa01.idm.lab.test`.

## 4. Validare Kerberos e API FreeIPA

**Macchina:** `ipa01`

```bash
kinit admin
klist
ipa ping
```

Password LAB:

`12345678`

Il laboratorio ha prodotto un TGT `krbtgt/IDM.LAB.TEST@IDM.LAB.TEST` e:

```text
IPA server version 4.13.4. API version 2.257
```

## 5. Creare utente e gruppo IdM

```bash
ipa user-add ipauser01 \
    --first="IPA" \
    --last="User01" \
    --password
```

Impostare `12345678` come password temporanea. Al primo:

```bash
kinit ipauser01
```

FreeIPA impone il cambio password. Nel LAB la nuova password è `123456789`.

Riprendere quindi un ticket amministrativo e creare il gruppo:

```bash
kdestroy
kinit admin

ipa group-add labadmins \
    --desc="Amministratori del laboratorio Linuxshell"

ipa group-add-member labadmins \
    --users=ipauser01

ipa group-show labadmins
```

## 6. Registrare linux-client01

Prima dell'enrollment proteggere lo stato del Capitolo 14:

```powershell
Checkpoint-VM `
    -Name "linux-client01" `
    -SnapshotName "CH15-PRE-FREEIPA-ENROLLMENT"
```

**Macchina:** `linux-client01`

```bash
sudo apt update
sudo apt install -y freeipa-client
```

Durante la configurazione Kerberos usare:

- realm: `IDM.LAB.TEST`;
- KDC: `ipa01.idm.lab.test`;
- administrative server: `ipa01.idm.lab.test`.

Prima dell'enrollment verificare:

```bash
sudo resolvectl flush-caches
getent ahostsv4 ipa01.idm.lab.test

ldapsearch \
    -x \
    -H ldap://ipa01.idm.lab.test \
    -s base \
    -b "" \
    namingContexts
```

Il nome deve risolvere a `10.77.0.70` e LDAP deve mostrare almeno `dc=idm,dc=lab,dc=test`.

Lo script validato di enrollment è:

`client/ipa-client-install.sh`

Eseguirlo con:

```bash
sudo bash client/ipa-client-install.sh
```

Risultato validato:

```text
Enrolled in IPA realm IDM.LAB.TEST
Client configuration complete.
The ipa-client-install command was successful
```

## 7. Verificare identità, Kerberos e login

```bash
systemctl is-active sssd
getent passwd ipauser01
id ipauser01

grep '^ipauser01:' /etc/passwd \
    || echo "ipauser01 non è presente nel file locale /etc/passwd"
```

`ipauser01` deve essere risolto da SSSD senza comparire in `/etc/passwd`.

Ticket Kerberos dal client:

```bash
kdestroy 2>/dev/null || true
kinit ipauser01
klist
```

Password: `123456789`.

Login reale:

```bash
kdestroy
su - ipauser01
```

Nella sessione:

```bash
whoami
pwd
id
ls -ld /home/ipauser01
exit
```

La home deve essere `/home/ipauser01`.

## 8. Policy sudo centralizzata

Sul server `ipa01`, con ticket amministrativo valido, eseguire:

```bash
bash policy/sudo-labadmins-whoami.sh
```

La policy autorizza il gruppo `labadmins`, esclusivamente su `linux-client01.lab.test`, a eseguire come root soltanto:

`/usr/bin/whoami`

Sul client riutilizzato dal Capitolo 14 è stata necessaria la correzione del responder sudo SSSD. Lo script validato è:

`client/sssd-sudo-fix.sh`

Eseguirlo su `linux-client01`:

```bash
sudo bash client/sssd-sudo-fix.sh
```

Verifica:

```bash
su - ipauser01
sudo -l
sudo /usr/bin/whoami
sudo /usr/bin/id
```

Risultato validato:

- `sudo -l` elenca `(root) /usr/bin/whoami`;
- `sudo /usr/bin/whoami` restituisce `root`;
- `sudo /usr/bin/id` viene rifiutato.

## 9. Troubleshooting validato

### ipa-client-install segnala LDAP non raggiungibile

Nel laboratorio TCP/389 e LDAP per IP funzionavano, ma LDAP per hostname no. Il DNS parent restituiva `NXDOMAIN`.

Diagnosi:

```bash
getent ahostsv4 ipa01.idm.lab.test

timeout 3 bash -c \
    'cat < /dev/null > /dev/tcp/10.77.0.70/389' \
    && echo "TCP 389 OK" \
    || echo "TCP 389 NON RAGGIUNGIBILE"

ldapsearch -x -H ldap://10.77.0.70 -s base -b "" namingContexts
ldapsearch -x -H ldap://ipa01.idm.lab.test -s base -b "" namingContexts

resolvectl status
dig @10.77.0.10 ipa01.idm.lab.test A +comments +authority +additional
```

Causa: `forward only` globale su `infra01`.  
Correzione: forward zone specifica `idm.lab.test -> 10.77.0.70`.

### La sudo rule esiste ma il client la rifiuta

Il client aveva contemporaneamente:

- `sudo` nella riga `services` di `sssd.conf`;
- `sssd-sudo.socket` abilitato.

Systemd riportava:

`Misconfiguration found for the sudo responder`

Nel LAB è stata mantenuta la modalità socket-activated rimuovendo `sudo` da `services`. La correzione è raccolta in `client/sssd-sudo-fix.sh`.

## 10. Gestione su scala

La procedura manuale serve a comprendere i singoli strati. Con centinaia o migliaia di utenti/client si usano:

- gruppi di utenti e gruppi di host;
- sudo rule e HBAC applicate ai gruppi;
- automember;
- ruoli e privilegi amministrativi delegati;
- enrollment automatizzato;
- Ansible, inventory e playbook;
- OTP, keytab o secret management invece di password amministrative distribuite;
- repliche FreeIPA/IdM per disponibilità e capacità.

Il laboratorio manuale resta quindi il modello diagnostico delle automazioni.

## Materiale escluso dal repository

Non versionare:

- `/root/cacert.p12`;
- chiavi private della CA;
- `/etc/krb5.keytab`;
- host key private;
- password o token reali;
- backup contenenti segreti;
- dump LDAP/IdM contenenti dati sensibili.

Le password numeriche presenti in questo README sono esclusivamente credenziali dichiarate del LAB.
