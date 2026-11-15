# Capitolo 11 – Proxy, TLS, certificati e pubblicazione dei servizi

Materiale operativo associato al Capitolo 11 di **Noi Amministriamo Infrastrutture Linux**.

## Architettura validata

- `rp01` — `10.77.0.50/24`
  - Nginx HTTP `:80`
  - Nginx HTTPS `:443`
  - HAProxy HTTP `:8080`
  - HAProxy HTTPS `:8443`
- `web01` — `10.77.0.51/24` — Apache HTTP backend `:80`.
- `linux-client01` — `10.77.0.101/24` — client con Linuxshell Lab CA installata nel trust store.

## Concetti validati

- CA locale didattica con chiave RSA 4096 bit e certificato `CA:TRUE`.
- due certificati server distinti per `sito1.lab.test` e `sito2.lab.test`.
- SAN corretto, `serverAuth`, seriali distinti, chain verify `OK`.
- Nginx seleziona il certificato corretto via SNI su `10.77.0.50:443`.
- HAProxy seleziona il certificato corretto via SNI su `10.77.0.50:8443`.
- prima del trust della CA: `curl` fallisce con exit 60.
- dopo il trust della CA: HTTPS funziona senza `-k`.
- TLS 1.2 e TLS 1.3 validati su Nginx e HAProxy.
- TLS termina su `rp01`; Apache resta HTTP e riceve `X-Forwarded-Proto`.

## Sicurezza dei materiali crittografici

Nel repository NON vengono pubblicate:

- la chiave privata della Linuxshell Lab CA;
- le chiavi private di `sito1` e `sito2`;
- i PEM HAProxy contenenti chiave privata;
- certificati generati nel laboratorio quando non necessari alla riproduzione.

Il repository contiene invece le procedure e le configurazioni necessarie a rigenerare il materiale.

## File

- `pki/sito1.ext`, `pki/sito2.ext` — estensioni server certificate.
- `pki/create-lab-ca-and-server-certs.sh` — procedura automatizzata di laboratorio.
- `nginx/sito1.conf`, `nginx/sito2.conf` — configurazioni HTTP/HTTPS.
- `haproxy/crt-list.txt` — associazione PEM/SNI.
- `haproxy/haproxy.cfg` — configurazione HTTP/HTTPS.
- `apache/proxy-log.conf` — log di `X-Forwarded-For` e `X-Forwarded-Proto`.
- `linux/install-lab-ca-client.sh` — installazione della CA pubblica sul client.
- `linux/configure-rp01-ufw.sh` — regole UFW finali.
- `linux/verify-final-state.sh` — verifica finale.
- `rollback/README.md` — checkpoint e rollback.

## Nota

La Lab CA è volutamente minima e serve solo a rendere riproducibile il laboratorio TLS. Una PKI completa, con lifecycle, revoca e separazione dei ruoli, è rinviata al capitolo dedicato.
