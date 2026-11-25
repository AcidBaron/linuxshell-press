# Capitolo 21 — Alta disponibilità: concetti e architetture

Materiale operativo del Capitolo 21 di **Noi Amministriamo Infrastrutture Linux**.

Questo capitolo individua i punti singoli di guasto nell'infrastruttura esistente e prepara i capitoli 22 (Keepalived/VRRP) e 23 (Pacemaker/Corosync). **Non è stato implementato alcun cluster o VIP in questo capitolo.**

## Regola vincolante: riuso delle VM

- Riutilizzare VM e servizi già presenti.
- Aggiungere un ruolo a una VM solo se non compromette i servizi validati.
- Creare una nuova VM soltanto quando risulta una necessità tecnica dimostrata; al momento questa necessità non è stata dimostrata.
- Conservare il rollback delle modifiche che saranno introdotte nei capitoli successivi.

## Componenti e dipendenze

| VM/elemento | Ruolo attuale | Limite di disponibilità |
|---|---|---|
| infra01 (10.77.0.10) | DNS BIND, zona lab.test | Risoluzione nomi |
| rp01 (10.77.0.50) | Nginx, HAProxy, TLS | Punto di ingresso HTTPS |
| web01 (10.77.0.51) | Apache, Nextcloud, MariaDB | Applicazione e dati |
| fw01 (10.77.0.1) | Gateway e firewall | Connettività nei percorsi che attraversano il gateway |
| Host Hyper-V | Esecuzione delle VM | Guasto fisico comune alle VM ospitate |

Per due host nella stessa LAB-LAN il traffico locale **può non attraversare fw01**: il suo impatto dipende dal percorso.

## Laboratorio realmente eseguito — 25 novembre 2026

Si è fermato volontariamente Nginx su rp01, verificato che il client non riusciva a raggiungere Nextcloud su 443, riavviato Nginx e verificato il ritorno del redirect HTTPS al login.

Vedere [laboratorio/01-nginx-spof-stop-start.md](./laboratorio/01-nginx-spof-stop-start.md) per comandi, risultati, limiti dell'evidenza e ripristino.

**PASS:** URL non raggiungibile con Nginx fermo; HTTP 302 dopo il ripristino.

**Non misurato:** RTO, stato del backend durante lo stop, eventuali perdite di sessione. Nessun dato consente di affermare che l'intera piattaforma sia già HA.

## Progetto per il Capitolo 22

- rp01 rimane il punto di riferimento del reverse proxy già validato;
- seconda VM **esistente da scegliere**, non ancora identificata;
- VIP **da definire dopo** verifica della rete e dei conflitti;
- Keepalived e health check da installare e testare successivamente;
- non modificare per ora il DNS di nextcloud.lab.test;
- il solo failover proxy lascia web01/MariaDB come SPOF;
- due VM sullo stesso host Hyper-V non proteggono dal guasto fisico dell'host.

Vedere [progetto/criteri-capitolo-22.md](./progetto/criteri-capitolo-22.md).

## Concetti trattati nel libro

- alta disponibilità versus backup e disaster recovery;
- SPOF e failure domain;
- SLO/SLA, RTO e RPO;
- active/passive versus active/active;
- VIP, VRRP, health check, failover e failback;
- limiti della continuità delle connessioni;
- quorum, split-brain e fencing (approfondimento operativo nel Capitolo 23).

## Riferimenti

- NIST SP 800-34 Rev.1: https://csrc.nist.gov/pubs/sp/800/34/r1/upd1/final
- Red Hat RHEL 9 High Availability Add-On: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/configuring_and_managing_high_availability_clusters/assembly_overview-of-high-availability-configuring-and-managing-high-availability-clusters
- Keepalived: https://www.keepalived.org/documentation/

Non sono state generate nuove password, chiavi o configurazioni cluster in questo capitolo.
