# Capitolo 22 — Keepalived e VRRP

Materiale operativo per **Noi Amministriamo Infrastrutture Linux** (Linuxshell Press).

## Stato finale validato (25 novembre 2026)

Il laboratorio realizza un failover **active/passive** per l'accesso HTTPS a Nextcloud, usando esclusivamente VM preesistenti:

| Macchina | IP stabile | Ruolo |
|---|---|---|
| rp01 | 10.77.0.50 | Nginx + HAProxy, primario VRRP |
| proxy01 | 10.77.0.40 | Squid/3128 + Nginx, standby VRRP |
| web01 | 10.77.0.51 | Apache, Nextcloud, MariaDB |
| infra01 | 10.77.0.10 | DNS autorevole lab.test |
| VIP | 10.77.0.90/24 | Indirizzo HTTPS condiviso |

- Interfaccia: eth0, switch LAB-LAN.
- VRID: 22; priorità rp01 150, proxy01 100.
- Annunci VRRP v3 in unicast (protocollo IP 112).
- Controllo Nginx con systemctl e weight 0, fall 2, rise 2.
- DNS finale: nextcloud.lab.test A 10.77.0.90 (SOA 2026112501).
- Nextcloud riconosce rp01 e proxy01 tra i trusted_proxies.
- Entrambi i reverse proxy inoltrano il VirtualHost Nextcloud su web01.
- Certificato e chiave privata TLS condivisi **solo sulle due VM**; nessuna chiave pubblicata in GitHub.

## Verifiche realmente eseguite

- Squid e Nginx attivi contemporaneamente su proxy01: PASS.
- HTTPS su proxy01 con curl --resolve: HTTP 302 PASS.
- Validazione keepalived -t su entrambi: PASS.
- Avvio di proxy01: acquisizione temporanea VIP.
- Avvio di rp01: MASTER con VIP esclusiva, proxy01 senza VIP.
- Guasto simulato: stop nginx su rp01 → VIP su proxy01.
- Curl HTTPS attraverso VIP dopo failover → HTTP 302.
- Start nginx su rp01 → VIP torna al primario (failback).
- Dopo la modifica DNS, test senza --resolve: **HTTP=302 IP=10.77.0.90** durante guasto.
- Ritorno VIP su rp01 al riavvio Nginx.
- Checkpoint finali creati su rp01, proxy01, web01, infra01: CH22-KEEPALIVED-VRRP-COMPLETE.
- Checkpoint temporaneo CH22-PRE-HA-STANDBY su proxy01 rimosso.

Non sono stati misurati RTO quantitativi né continuità delle connessioni già aperte.

## File

- [config/rp01.keepalived.conf](config/rp01.keepalived.conf) — file del primario.
- [config/proxy01.keepalived.conf](config/proxy01.keepalived.conf) — file dello standby.
- [procedure/01-preparare-standby.md](procedure/01-preparare-standby.md) — Nginx, trasferimento TLS, firewall, trusted proxy.
- [procedure/02-attivare-vrrp.md](procedure/02-attivare-vrrp.md) — VRRP, health check, installazione, avvio e VIP.
- [procedure/03-dns-e-collaudo.md](procedure/03-dns-e-collaudo.md) — BIND, failover, failback, test finale.
- [rollback/README.md](rollback/README.md) — rollback mirato.

Configurazione Nginx riutilizzata dal Capitolo 20:
[capitolo-20-nextcloud/nginx/nextcloud.conf](../capitolo-20-nextcloud/nginx/nextcloud.conf).

## Limiti

La ridondanza protegge **solo il reverse proxy Nextcloud**. Il backend web01/MariaDB e l'unico host fisico Hyper-V rimangono SPOF. La configurazione di altri siti pubblicati su rp01 non è stata replicata né validata come HA. Nessuna nuova VM è stata creata.

Le procedure collegate raccolgono i comandi eseguiti durante la sessione; i file .conf sono stati applicati nella configurazione. Un insieme di comandi raggruppati in una procedura GitHub non implica che sia stato eseguito come script automatizzato unico.
