# Capitolo 10 – Reverse proxy con Nginx e HAProxy

Materiale operativo associato al Capitolo 10 di **Noi Amministriamo Infrastrutture Linux**.

## Topologia validata

- `rp01` — `10.77.0.50/24` — Nginx su TCP/80, HAProxy su TCP/8080.
- `web01` — `10.77.0.51/24` — Apache con due VirtualHost: `sito1.lab.test` e `sito2.lab.test`.
- `sito1.lab.test` e `sito2.lab.test` risolvono entrambi verso `rp01` (`10.77.0.50`).
- `web01.lab.test` risolve verso `10.77.0.51`.

## Stato finale validato

- Nginx `1.24.0-2ubuntu7.19`.
- HAProxy `2.8.30-0ubuntu0.24.04.2`.
- Apache `2.4.58-1ubuntu8.19`.
- routing per hostname funzionante con Nginx e HAProxy.
- `X-Forwarded-For` preserva il client originale `10.77.0.101`.
- Nginx inoltra `Host` senza la porta usando `$host`.
- HAProxy conserva l'header Host originale, quindi su porta 8080 Apache registra anche `:8080`.
- host non pubblicato su HAProxy -> HTTP 404.
- `web01:80` accetta connessioni solo da `rp01` (`10.77.0.50`).
- accesso diretto al backend da `linux-client01` bloccato sia IPv4 sia IPv6.
- reboot completo: Nginx, HAProxy, Apache e UFW persistono e i due siti restano raggiungibili.

## Checkpoint Hyper-V

- `CH10-RP01-PRE-REVERSE-PROXY`
- `CH10-WEB01-PRE-APACHE`
- `CH10-WEB01-VHOSTS-VALIDATED`
- `CH10-NGINX-REVERSE-PROXY-VALIDATED`
- `CH10-WEB01-PROXY-LOGS-VALIDATED`
- `CH10-RP01-FINAL-VALIDATED`
- `CH10-WEB01-FINAL-VALIDATED`

## File

- `nginx/sito1.conf`, `nginx/sito2.conf` — server block Nginx.
- `haproxy/haproxy.cfg` — configurazione HAProxy validata.
- `apache/servername.conf` — ServerName globale.
- `apache/proxy-log.conf` — formato log con X-Forwarded-For.
- `apache/sito1.conf`, `apache/sito2.conf` — VirtualHost Apache.
- `apache/sito1-index.html`, `apache/sito2-index.html` — contenuti di test.
- `dns/ch10.records` — record A/PTR del capitolo.
- `linux/configure-rp01-ufw.sh`, `linux/configure-web01-ufw.sh` — firewall finali.
- `linux/verify-final-state.sh` — controlli conclusivi.
- `rollback/README.md` — checkpoint e backup disponibili.

## Risultati chiave

- `linux-client01 -> web01:80` diretto: BLOCCATO.
- `linux-client01 -> rp01:80 -> web01:80`: PASS con Nginx.
- `linux-client01 -> rp01:8080 -> web01:80`: PASS con HAProxy.
- `X-Forwarded-For=10.77.0.101` osservato nei log Apache.
- `client=10.77.0.50` osservato sul backend: la connessione TCP viene aperta dal reverse proxy.
- accesso diretto IPv6 al backend: BLOCCATO.
