# Capitolo 25 — Load balancing avanzato con HAProxy

Materiali tecnici del laboratorio **validato fino al 28 novembre 2026** per *Noi Amministriamo Infrastrutture Linux* (Linuxshell Press).

## Topologia

| Ruolo | Host | IP |
|---|---|---|
| Bilanciatore | rp01 | 10.77.0.50 |
| Backend A | linux-client01 | 10.77.0.101 |
| Backend B | dhcp-client01 | 10.77.0.150 |

HAProxy 2.8.30 su rp01: frontend `fe_ch25` TCP/8081, backend `be_ch25` in HTTP; Nginx 1.24 su entrambi i backend (TCP/80). L'applicazione CPU-bound è Fibonacci(40), Python CGI attraverso `fcgiwrap`, raggiungibile come `/fibonacci`. Health check `GET /backend.txt`. La configurazione preesistente di rp01 per le porte 8080/8443 viene preservata.

## File

- [Frammento HAProxy validato](config/haproxy-ch25.cfg): **estratto da integrare** nella configurazione esistente, non file completo da sovrascrivere.
- [Location Nginx](config/nginx-fibonacci-location.conf): inserire nel `server` esistente `/etc/nginx/sites-available/ch23-ha` su ciascun nodo.
- [Applicazione CGI](linux/ch25-fibonacci.py): copiare in `/usr/lib/cgi-bin/ch25-fibonacci.py`, rendere eseguibile, adattare la sola stringa di identificazione backend.
- [Procedura verificata](procedure/01-laboratorio-validato.md): installazione, test, statistiche e risultati.
- [Pulizia e rollback](rollback/README.md): inclusa eliminazione del file di prova creato con `truncate`.

## Prove validate

1. Round Robin: alternanza di A/B con 10 richieste, 5 per nodo, e failover al fermo di Nginx su B, con reinserimento automatico dopo il riavvio.
2. Least Connections: 6 Fibonacci simultanei, **3 su A e 3 su B**; tempi HTTP osservati in coppie di circa 6,3 / 12,6 / 18,9 s a causa dell'elaborazione CGI serializzata per nodo.
3. Socket amministrativo locale `/run/haproxy/admin.sock`: durante sei elaborazioni `scur=3+3`, a riposo `scur=0+0`, `qcur=0`.
4. Due richieste sfalsate di 1 secondo: prima A (calcolo 6,330 s), seconda B (6,316 s); contatori `stot` da 3+3 a 4+4. Comportamento **coerente** con `leastconn`, senza regole `use-server` o backend forzati.

## Limiti e cautele

- L'elaborazione Fibonacci ricorsiva serve esclusivamente a produrre carico CPU didattico; non è un'applicazione di produzione.
- La prova a due richieste è evidenza pratica compatibile con l'algoritmo, non un confronto sperimentale completo fra algoritmi.
- I cluster Pacemaker/Corosync dei due nodi restano fermati per questo laboratorio.
- Le verifiche su persistenza sessioni, terminazione TLS e ulteriori algoritmi non fanno parte del checkpoint qui consolidato.
- Non pubblicare chiavi private, certificati, password o file integrali non revisionati.
