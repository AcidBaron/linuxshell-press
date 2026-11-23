# Capitolo 19 — PKI e gestione dei certificati

Materiale operativo del Capitolo 19 di **Noi Amministriamo Infrastrutture Linux**.

Il laboratorio evolve la Linuxshell Lab CA del Capitolo 11 in una PKI gestita a due livelli:

```text
Linuxshell Lab CA (Root)
        |
        +-- Linuxshell Lab Issuing CA
                |
                +-- sito1.lab.test
```

La Root CA resta il trust anchor distribuito ai client; la Issuing CA intermedia gestisce emissione, seriali, stato dei certificati, revoca e CRL.

## Stato validato

- host PKI/reverse proxy: `rp01`
- Root CA esistente: `/etc/ssl/linuxshell-lab-ca`
- Issuing CA: `/etc/ssl/linuxshell-lab-ca/issuing-ca`
- primo certificato gestito: `sito1.lab.test.managed-v1.crt`, seriale `1000`
- certificato corrente: `sito1.lab.test.managed-v2.crt`, seriale `1001`
- managed-v1: revocato, reason `superseded`
- CRL: `linuxshell-lab-issuing-ca.crl`
- Nginx `:443`: presenta managed-v2 + Issuing CA
- HAProxy `:8443`: presenta managed-v2 + Issuing CA
- linux-client01: continua a fidarsi soltanto della Root CA
- checkpoint finale: `CH19-PKI-LIFECYCLE-COMPLETE`

## File operativi

- `pki/openssl.cnf` — configurazione della Issuing CA.
- `pki/intermediate.ext` — estensioni della CA intermedia.
- `pki/01-create-issuing-ca.sh` — struttura, database, chiave, CSR e firma dell'intermedia.
- `pki/02-certificate-lifecycle.sh` — emissione v1, rekey v2, revoca e CRL.
- `linux/03-deploy-managed-v2.sh` — deployment validato su Nginx e HAProxy.
- `rollback/README.md` — ripristino dei materiali TLS e checkpoint.

## 1. Punto di partenza dal Capitolo 11

La Root CA esistente è self-signed, con `CA:TRUE` e key usage `Certificate Sign, CRL Sign`. I certificati del Capitolo 11 erano firmati direttamente dalla Root e non erano registrati in un database CA.

Prima del lifecycle:

```powershell
Checkpoint-VM `
    -Name "rp01" `
    -SnapshotName "CH19-PRE-PKI-LIFECYCLE"
```

## 2. Creare la Issuing CA

Eseguire i comandi raccolti in `pki/01-create-issuing-ca.sh`.

La CA gestita usa `index.txt`, `serial`, `crlnumber`, `newcerts/` e `crl/`.

L'intermedia è firmata dalla Root con `CA:TRUE, pathlen:0` e verifica correttamente contro la Root.

## 3. Emettere il primo certificato gestito

La procedura `pki/02-certificate-lifecycle.sh` usa `openssl ca` per emettere `managed-v1`.

Stato validato: seriale `1000`, issuer Linuxshell Lab Issuing CA, SAN `DNS:sito1.lab.test`, voce `V` in `index.txt`, next serial `1001`.

## 4. Rekey e nuova emissione

Viene generata una nuova chiave privata per `managed-v2`, quindi il rinnovo è un vero rekey.

Stato validato: managed-v2 seriale `1001`, next serial `1002`, chain verify `OK`.

## 5. Revoca e CRL

`managed-v1` viene revocato con reason `superseded`.

La Issuing CA genera `/etc/ssl/linuxshell-lab-ca/issuing-ca/crl/linuxshell-lab-issuing-ca.crl`.

Con `openssl verify -crl_check`: managed-v1 viene rifiutato come `certificate revoked`; managed-v2 resta `OK`.

## 6. Deployment su Nginx

Backup creati:

```text
/etc/nginx/tls/sito1.lab.test.crt.pre-ch19
/etc/nginx/tls/sito1.lab.test.key.pre-ch19
```

Nginx riceve certificato server managed-v2, Issuing CA intermedia e chiave privata managed-v2. La Root CA non viene inclusa nella chain servita.

`nginx -t` è stato validato prima del reload.

## 7. Verifica dal client

`linux-client01` non riceve la Issuing CA nel trust store.

La verifica end-to-end restituisce HTTP 200, issuer Linuxshell Lab Issuing CA e `Verify return code: 0 (ok)`.

## 8. Deployment su HAProxy

Backup: `/etc/haproxy/certs/sito1.lab.test.pem.pre-ch19`.

Il nuovo PEM contiene server certificate, Issuing CA certificate e private key.

`haproxy -c` è stato validato prima del reload. La verifica su `:8443` restituisce HTTP 200 e `Verify return code: 0 (ok)`.

## 9. Chiusura

```powershell
Checkpoint-VM `
    -Name "rp01" `
    -SnapshotName "CH19-PKI-LIFECYCLE-COMPLETE"

Remove-VMSnapshot `
    -VMName "rp01" `
    -Name "CH19-PRE-PKI-LIFECYCLE"
```

## Sicurezza dei materiali

Non versionare chiavi private della Root CA, Issuing CA o certificati server, né PEM HAProxy contenenti chiavi private. Il repository contiene soltanto procedure, configurazioni e metadati necessari a ricostruire il laboratorio.
