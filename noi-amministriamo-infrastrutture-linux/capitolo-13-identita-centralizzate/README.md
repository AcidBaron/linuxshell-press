# Capitolo 13 — Directory e identità centralizzate

Materiale operativo del Capitolo 13 di **Noi Amministriamo Infrastrutture Linux**.

Questo capitolo fissa la baseline delle identità prima dei laboratori dedicati a LDAP/OpenLDAP, FreeIPA/IdM e Active Directory. Non installa ancora alcun server di directory: dimostra che gli host del laboratorio usano identità locali indipendenti e verifica da quali sorgenti NSS risolve utenti e gruppi.

Verifica tecnologica e laboratorio: **17 novembre 2026**.

## Criterio di selezione delle tecnologie

Il libro privilegia tecnologie con diffusione e supporto concreti, evitando di assegnare lo stesso peso a strumenti con impatto operativo molto diverso.

- **Active Directory Domain Services**: piattaforma centrale negli ambienti Windows e misti.
- **SSSD**: componente centrale lato Linux per l'integrazione con AD, IdM e provider LDAP/Kerberos.
- **realmd / adcli**: strumenti di discovery e join, non directory autonome.
- **Kerberos**: tecnologia abilitante essenziale per l'autenticazione a ticket.
- **FreeIPA / Red Hat Identity Management**: piattaforma integrata rilevante negli ambienti Linux-centrici.
- **LDAP**: protocollo fondamentale.
- **OpenLDAP standalone**: mantenuto con un laboratorio essenziale, senza attribuirgli il peso delle piattaforme integrate.
- **Trust IdM–AD**: scenario avanzato da trattare dopo la validazione separata dei due ambienti.

## Baseline del laboratorio

VM utilizzate:

- `infra01`
- `files01`

Il laboratorio non lascia modifiche persistenti. L'unico utente creato per il failure test viene eliminato al termine.

### 1. Fotografare le identità locali su `infra01`

**Macchina:** `infra01`  
**Shell:** Bash/Linux

```bash
echo "===== CAP13 - IDENTITA LOCALI SU INFRA01 ====="

getent passwd |
awk -F: '$3 >= 1000 && $3 < 65534 {
    printf "%-20s UID=%-6s GID=%-6s HOME=%s\n",$1,$3,$4,$6
}'

echo
echo "===== GRUPPI DEGLI UTENTI UMANI ====="

getent passwd |
awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' |
while read -r user; do
    id "$user"
done
```

Risultato validato:

```text
labadmin             UID=1000   GID=1000   HOME=/home/labadmin

uid=1000(labadmin) gid=1000(labadmin) groups=1000(labadmin),4(adm),24(cdrom),27(sudo),30(dip),46(plugdev),101(lxd)
```

Lo stesso controllo su `files01` ha restituito lo stesso account e gli stessi identificatori. Questo deriva dal provisioning uniforme delle VM e **non** dimostra che l'identità sia centralizzata.

### 2. Creare una identità soltanto su `infra01`

**Macchina:** `infra01`  
**Shell:** Bash/Linux

```bash
sudo useradd \
    --create-home \
    --shell /bin/bash \
    cap13-localtest

getent passwd cap13-localtest
id cap13-localtest
```

Risultato validato:

```text
cap13-localtest:x:1001:1001::/home/cap13-localtest:/bin/bash
uid=1001(cap13-localtest) gid=1001(cap13-localtest) groups=1001(cap13-localtest)
```

Non viene impostata alcuna password: l'account serve solo a dimostrare il modello locale.

### 3. Verificare che `files01` non conosca l'utente

**Macchina:** `files01`  
**Shell:** Bash/Linux

```bash
getent passwd cap13-localtest || \
    echo "cap13-localtest: NON PRESENTE su files01"

id cap13-localtest 2>/dev/null || \
    echo "id: utente cap13-localtest sconosciuto su files01"
```

Risultato validato:

```text
cap13-localtest: NON PRESENTE su files01
id: utente cap13-localtest sconosciuto su files01
```

Questa è la prova centrale del capitolo: lo stesso nome non viene condiviso automaticamente tra host perché non esiste ancora una autorità di identità comune.

### 4. Verificare le sorgenti NSS

**Macchina:** `infra01`  
**Shell:** Bash/Linux

```bash
grep -E '^(passwd|group|shadow):' /etc/nsswitch.conf
```

Risultato validato:

```text
passwd:         files systemd
group:          files systemd
shadow:         files systemd
```

Non compare ancora `sss` e non è configurato alcun provider LDAP, AD o IdM.

### 5. Rollback

**Macchina:** `infra01`  
**Shell:** Bash/Linux

```bash
sudo userdel \
    --remove \
    cap13-localtest

getent passwd cap13-localtest || \
    echo "cap13-localtest rimosso correttamente"
```

Risultato validato:

```text
cap13-localtest rimosso correttamente
```

## Cosa cambierà nei capitoli successivi

Con una directory centralizzata un host potrà risolvere un utente che non esiste nel proprio `/etc/passwd`. SSSD si integrerà con NSS e PAM e interrogherà il provider configurato.

Percorso editoriale:

- **Capitolo 14** — LDAP e OpenLDAP: directory essenziale, utenti/gruppi, query, TLS e client Linux.
- **Capitolo 15** — FreeIPA / Identity Management: directory, Kerberos, policy e client enrollment.
- **Capitolo 16** — Active Directory e integrazione Linux: dominio Windows e host Linux joinato.
- SSSD, `realmd`, `adcli` e Kerberos vengono approfonditi dentro questi flussi.
- Il trust IdM–AD viene trattato come scenario avanzato.

## Sicurezza

Non pubblicare nel repository:

- `/etc/shadow`;
- hash di password;
- credenziali reali;
- dump contenenti segreti o dati personali.

Il Capitolo 13 non richiede file di configurazione permanenti né ulteriori script: i comandi sopra costituiscono l'intero materiale operativo riproducibile.
