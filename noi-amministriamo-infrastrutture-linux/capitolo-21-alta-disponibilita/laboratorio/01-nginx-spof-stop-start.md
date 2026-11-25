# Laboratorio 21 — Un Single Point of Failure osservato

**Data della prova:** 25 novembre 2026.

**Precondizione:** Nextcloud del Capitolo 20 accessibile da linux-client01 attraverso HTTPS, con Nginx su rp01.

**Rischio:** il primo comando interrompe temporaneamente gli URL serviti da Nginx. Usarlo solo in laboratorio, con la possibilità di raggiungere rp01 per il ripristino.

## 1. Su rp01 — Bash

Fermare Nginx:

```bash
sudo systemctl stop nginx
```

## 2. Su linux-client01 — Bash

Verificare il percorso HTTPS, con timeout espliciti:

```bash
curl -I \
    --connect-timeout 3 \
    --max-time 5 \
    https://nextcloud.lab.test/
```

**Output osservato (estratto):**

```text
curl: (7) Failed to connect to nextcloud.lab.test port 443
after 1 ms: Couldn't connect to server
```

## 3. Su rp01 — Bash

Ripristinare immediatamente Nginx:

```bash
sudo systemctl start nginx
```

## 4. Su linux-client01 — Bash

Ripetere la verifica:

```bash
curl -I \
    https://nextcloud.lab.test/
```

**Output osservato (estratto):**

```text
HTTP/1.1 302 Found
Server: nginx/1.24.0 (Ubuntu)
Location: https://nextcloud.lab.test/index.php/login
Strict-Transport-Security: max-age=15552000
```

## Risultato e limiti

- **PASS:** Nginx fermato → percorso HTTPS non raggiungibile sul servizio testato.
- **PASS:** Nginx ripristinato → risposta HTTP 302 verso login Nextcloud e header HSTS.
- **Non misurato:** tempo di recupero continuo / RTO.
- **Non verificato durante lo stop:** la risposta diretta di web01 e la continuità delle sessioni.
- **Non implementato:** failover automatico, VIP o seconda VM proxy.

**Nessun checkpoint aggiuntivo è stato richiesto per questo test reversibile.**

Il test giustifica la progettazione di una ridondanza sul punto di ingresso, ma **non dimostra** un sistema già in alta disponibilità.
