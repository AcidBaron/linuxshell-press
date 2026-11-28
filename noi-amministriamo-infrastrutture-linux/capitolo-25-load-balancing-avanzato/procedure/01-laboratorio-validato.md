# Capitolo 25 — Procedura operativa e verifiche

## Prerequisiti reali

- `rp01` 10.77.0.50, HAProxy 2.8.30 con `/etc/haproxy/haproxy.cfg` operativo. Conservare frontend precedenti 8080 e 8443.
- `linux-client01` 10.77.0.101 e `dhcp-client01` 10.77.0.150, Ubuntu 24.04, Nginx 1.24, `/etc/nginx/sites-available/ch23-ha`, root `/var/www/ch23-ha`.
- `/var/www/ch23-ha/backend.txt` serve testo identificativo differente sui due nodi; `index.html` già presente.
- Pacemaker/Corosync fermi durante il laboratorio. Non avviare il cluster.

## Configurazione

1. Salvare copia di `/etc/haproxy/haproxy.cfg` su rp01; aggiungere i blocchi in [config/haproxy-ch25.cfg](../config/haproxy-ch25.cfg) (inizialmente `balance roundrobin`).
2. Su entrambi i backend, avviare Nginx con `sudo systemctl start nginx`; verificare `curl http://IP/backend.txt`.
3. Convalidare HAProxy con `sudo haproxy -c -f /etc/haproxy/haproxy.cfg`; applicare con `sudo systemctl reload haproxy`.
4. Verificare dieci richieste `curl http://127.0.0.1:8081/backend.txt`: roundrobin ha restituito 5 A/5 B; fermando Nginx su B, HAProxy ha consegnato tutte ad A; riavviando Nginx su B, B è stato reinserito automaticamente.
5. Cambiare il solo `balance roundrobin` in `balance leastconn`; convalidare e ricaricare.
6. Installare `fcgiwrap` su A e B con `sudo apt install -y fcgiwrap`; verificare `systemctl status fcgiwrap.socket` e il socket `/run/fcgiwrap.socket`.
7. Installare [lo script](../linux/ch25-fibonacci.py) in `/usr/lib/cgi-bin/ch25-fibonacci.py`, `chmod 755`, personalizzando l'identità backend. Inserire la [location Nginx](../config/nginx-fibonacci-location.conf) nel virtual host esistente; `sudo nginx -t && sudo systemctl reload nginx`.
8. Verificare direttamente ciascun backend: `curl -fsS -w '\nTempo HTTP: %{time_total}s\n' http://127.0.0.1/fibonacci`. Risultato numerico `102334155`, tempo misurato ~6,2–6,4 secondi.
9. Abilitare nella sezione `global` di HAProxy `stats socket /run/haproxy/admin.sock mode 660 level admin`; verificare con `sudo haproxy -c ...`, ricaricare, controllare socket con `sudo ls -l /run/haproxy/admin.sock`.
10. Eseguire sei richieste concorrenti tramite `127.0.0.1:8081/fibonacci`. Durante l'esecuzione, interrogare il socket (vedere sotto).

## Lettura statistiche senza socat

```python
import socket, csv, io
with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
    s.connect("/run/haproxy/admin.sock")
    s.sendall(b"show stat\n")
    s.shutdown(socket.SHUT_WR)
    data = b""
    while chunk := s.recv(65536):
        data += chunk
for r in csv.DictReader(io.StringIO(data.decode().lstrip("# "))):
    if r["pxname"] == "be_ch25":
        print(r["svname"], "scur="+r["scur"], "qcur="+r["qcur"], "stot="+r["stot"])
```

Eseguire come root: `sudo python3` (ad esempio tramite heredoc). Il pacchetto `socat` **non era installato**; non è stato necessario aggiungerlo.

## Evidenze osservate il 28/11/2026

- 6 richieste concorrenti: 3 su A, 3 su B; tutte Fibonacci(40)=102334155; scur=3/3 durante il carico, qcur=0/0; dopo completamento scur=0/0, stot=3/3.
- Due richieste sfalsate di 1 s: A, calcolo 6,330 s; B, calcolo 6,316 s. Stot da 3/3 a 4/4 dopo il test, scur=0 e qcur=0.
- Due richieste dirette diverse da HAProxy **non** valgono come dimostrazione di leastconn: HAProxy non conteggia le connessioni originate esternamente.
- Warning sui backend `be_sito1`/`be_sito2` attribuibili a `web01` spento, non a `be_ch25`.
- Primo tentativo Nginx CGI su B: HTTP 404 temporaneo; dopo verifica di sito abilitato, location presente e script eseguibile, richiesta successiva HTTP 200. Causa non determinata, quindi non attribuirla a una correzione mai effettuata.

## Pulizia

Per rimuovere **solo** il file di prova sparse creato con `truncate -s 20M`: seguire [rollback/README.md](../rollback/README.md).

## Sicurezza e limiti

Socket admin locale `mode 660 level admin`: accesso limitato; evitare di esporlo in rete. `fcgiwrap` esegue script CGI: pubblicare solo endpoint esplicitamente previsti. Il test è didattico e non costituisce benchmark in produzione.
