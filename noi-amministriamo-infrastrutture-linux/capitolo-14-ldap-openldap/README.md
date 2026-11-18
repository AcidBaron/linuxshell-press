# Capitolo 14 — LDAP e OpenLDAP: una directory essenziale

Materiale operativo del Capitolo 14 di **Noi Amministriamo Infrastrutture Linux**.

Il laboratorio costruisce una directory OpenLDAP reale, crea una identità POSIX, abilita StartTLS con la Linuxshell Lab CA del Capitolo 11 e integra `linux-client01` tramite SSSD, NSS e PAM.

Verifica tecnologica e laboratorio: **17 novembre 2026**.

## Perimetro

- Server OpenLDAP: `ldap01.lab.test` — `10.77.0.60/24`
- Base DN: `dc=lab,dc=test`
- Utente: `ldapuser01` — UID/GID `20001`
- Gruppo: `labusers` — GID `20001`
- Client: `linux-client01` — `10.77.0.101/24`
- TLS: StartTLS sulla porta LDAP 389
- CA: Linuxshell Lab CA del Capitolo 11
- Password didattica LAB: `123`
- Fuori perimetro: replica, multi-master, overlay avanzati, tuning, HA e ACL articolate.

> **LAB ONLY:** la password `123` è dichiarata intenzionalmente per rendere il laboratorio riproducibile. Non è una pratica valida in produzione.

## Prerequisiti

Devono già esistere:

- `fw01` — `10.77.0.1/24`, gateway LAB-LAN;
- `infra01` — `10.77.0.10/24`, BIND autorevole per `lab.test` e `0.77.10.in-addr.arpa`;
- `rp01` — `10.77.0.50/24`, con Linuxshell Lab CA già creata;
- `linux-client01` — `10.77.0.101/24`;
- account `labadmin` con privilegi sudo;
- VM `ldap01` — `10.77.0.60/24`, registrata nel DNS come `ldap01.lab.test`.

La CA resta su `rp01`. Non copiare né pubblicare la chiave privata della CA.

## 1. Installare OpenLDAP

**Macchina:** `ldap01`  
**Shell:** Bash/Linux

```bash
sudo apt update
sudo apt install -y slapd ldap-utils
sudo dpkg-reconfigure slapd
```

Valori usati nel laboratorio:

- Omettere la configurazione OpenLDAP: **No**
- DNS domain name: `lab.test`
- Organization name: `Linuxshell Lab`
- Password amministratore LDAP: `123`
- Database backend: `MDB`
- Rimuovere il database al purge: **No**
- Spostare il vecchio database: **Yes**
- LDAPv2: **No**, se proposto

Risultato:

- Base DN: `dc=lab,dc=test`
- Administrator DN: `cn=admin,dc=lab,dc=test`

Verifica:

```bash
systemctl is-enabled slapd
systemctl is-active slapd

ldapsearch \
    -x \
    -H ldap://127.0.0.1 \
    -b dc=lab,dc=test \
    -LLL
```

`slapd` deve risultare `enabled` e `active`.

## 2. Creare il DIT

Struttura:

```text
dc=lab,dc=test
├── ou=People
│   └── uid=ldapuser01
└── ou=Groups
    └── cn=labusers
```

I file sono in `ldif/`.

**Macchina:** `ldap01`

```bash
ldapadd -x -H ldap://127.0.0.1 \
    -D "cn=admin,dc=lab,dc=test" -w 123 \
    -f ldif/00-ou.ldif

ldapadd -x -H ldap://127.0.0.1 \
    -D "cn=admin,dc=lab,dc=test" -w 123 \
    -f ldif/10-group-labusers.ldif

ldapadd -x -H ldap://127.0.0.1 \
    -D "cn=admin,dc=lab,dc=test" -w 123 \
    -f ldif/20-user-ldapuser01.ldif

ldappasswd \
    -x \
    -H ldap://127.0.0.1 \
    -D "cn=admin,dc=lab,dc=test" \
    -w 123 \
    -s 123 \
    "uid=ldapuser01,ou=People,dc=lab,dc=test"
```

Verifica del bind:

```bash
ldapwhoami \
    -x \
    -H ldap://127.0.0.1 \
    -D "uid=ldapuser01,ou=People,dc=lab,dc=test" \
    -w 123
```

Risultato atteso:

```text
dn:uid=ldapuser01,ou=People,dc=lab,dc=test
```

## 3. Certificato TLS

La chiave privata di `ldap01` viene generata localmente e **non va versionata**.

**Macchina:** `ldap01`

```bash
sudo install -d -o root -g openldap -m 0750 /etc/ldap/tls

sudo openssl genpkey \
    -algorithm RSA \
    -pkeyopt rsa_keygen_bits:2048 \
    -out /etc/ldap/tls/ldap01.lab.test.key

sudo chown root:openldap /etc/ldap/tls/ldap01.lab.test.key
sudo chmod 0640 /etc/ldap/tls/ldap01.lab.test.key

sudo openssl req \
    -new \
    -sha256 \
    -key /etc/ldap/tls/ldap01.lab.test.key \
    -out /tmp/ldap01.lab.test.csr \
    -subj "/C=IT/O=Linuxshell Press/OU=Laboratorio/CN=ldap01.lab.test" \
    -addext "subjectAltName=DNS:ldap01.lab.test"
```

La CSR viene firmata su `rp01` con la Linuxshell Lab CA usando `tls/ldap01.ext`.

Il certificato risultante deve avere:

- issuer: Linuxshell Lab CA;
- CN: `ldap01.lab.test`;
- SAN: `DNS:ldap01.lab.test`;
- `CA:FALSE`;
- Extended Key Usage: server authentication.

Le chiavi private **non devono entrare nel repository**.

## 4. Configurare StartTLS in cn=config

Dopo aver copiato su `ldap01` il certificato server e il certificato pubblico della CA:

```text
/etc/ldap/tls/ldap01.lab.test.crt
/etc/ldap/tls/linuxshell-lab-ca.crt
/etc/ldap/tls/ldap01.lab.test.key
```

applicare tramite `ldapmodify -Y EXTERNAL -H ldapi:///` questi attributi in `cn=config`:

```ldif
dn: cn=config
changetype: modify
replace: olcTLSCACertificateFile
olcTLSCACertificateFile: /etc/ldap/tls/linuxshell-lab-ca.crt
-
replace: olcTLSCertificateFile
olcTLSCertificateFile: /etc/ldap/tls/ldap01.lab.test.crt
-
replace: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/ldap/tls/ldap01.lab.test.key
```

Installare la CA pubblica anche nel trust store di `ldap01`:

```bash
sudo install -o root -g root -m 0644 \
    /tmp/linuxshell-lab-ca.crt \
    /usr/local/share/ca-certificates/linuxshell-lab-ca.crt

sudo update-ca-certificates
```

Verifica StartTLS:

```bash
ldapwhoami \
    -x \
    -ZZ \
    -H ldap://ldap01.lab.test

ldapwhoami \
    -x \
    -ZZ \
    -H ldap://ldap01.lab.test \
    -D "uid=ldapuser01,ou=People,dc=lab,dc=test" \
    -w 123
```

Risultati attesi:

```text
anonymous
dn:uid=ldapuser01,ou=People,dc=lab,dc=test
```

## 5. Integrare linux-client01 con SSSD

**Macchina:** `linux-client01`

```bash
sudo apt update
sudo apt install -y sssd-ldap ldap-utils
```

Il file validato è disponibile in `sssd/sssd.conf`. Dalla directory del capitolo installarlo così:

```bash
sudo install -o root -g root -m 0600 \\
    sssd/sssd.conf \\
    /etc/sssd/sssd.conf

sudo systemctl restart sssd
systemctl is-active sssd
```

SSSD deve risultare `active`.

Verificare che l'utente non sia locale:

```bash
grep '^ldapuser01:' /etc/passwd \
    || echo "ldapuser01 non presente in /etc/passwd"
```

Poi verificare NSS:

```bash
getent passwd ldapuser01
id ldapuser01
```

Risultato validato:

```text
ldapuser01:*:20001:20001:LDAP User 01:/home/ldapuser01:/bin/bash
uid=20001(ldapuser01) gid=20001(labusers) groups=20001(labusers)
```

## 6. PAM e home automatica

**Macchina:** `linux-client01`

```bash
sudo pam-auth-update --enable mkhomedir
su - ldapuser01
```

Password LAB:

```text
123
```

Nella sessione:

```bash
whoami
pwd
id
```

Risultato validato:

- utente `ldapuser01`;
- home `/home/ldapuser01`;
- UID/GID `20001`;
- gruppo `labusers`.

## Rollback del client

**Macchina:** `linux-client01`

```bash
sudo pam-auth-update --disable mkhomedir
sudo systemctl stop sssd
sudo mv /etc/sssd/sssd.conf /etc/sssd/sssd.conf.ch14-disabled

systemctl is-active sssd || true
getent passwd ldapuser01 || \
    echo "ldapuser01 non più risolto tramite SSSD"
```

La home già creata non viene cancellata automaticamente.

Riattivazione:

```bash
sudo mv /etc/sssd/sssd.conf.ch14-disabled /etc/sssd/sssd.conf
sudo chown root:root /etc/sssd/sssd.conf
sudo chmod 600 /etc/sssd/sssd.conf
sudo pam-auth-update --enable mkhomedir
sudo systemctl restart sssd

systemctl is-active sssd
getent passwd ldapuser01
```

## Materiale escluso dal repository

Non versionare:

- `linuxshell-lab-ca.key`;
- `ldap01.lab.test.key`;
- altre chiavi private;
- password reali;
- dump contenenti dati sensibili.

CSR e certificati pubblici non sono necessari nel repository: vengono generati durante il laboratorio.
