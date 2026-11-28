# Capitolo 25 — Pulizia e rollback mirati

## Eliminare il file temporaneo creato con truncate

Eseguire **separatamente su entrambi** i backend `linux-client01` e `dhcp-client01`:

```bash
ls -lh /var/www/ch23-ha/slow.bin
sudo rm -- /var/www/ch23-ha/slow.bin
test ! -e /var/www/ch23-ha/slow.bin && echo "slow.bin rimosso"
```

Il file `slow.bin` da 20 MiB era uno sparse file temporaneo per simulazioni di trasferimento lento. **Non eliminare** `index.html`, `backend.txt`, né l'intera directory `/var/www/ch23-ha`.

Su `rp01` i risultati di test `/tmp/ch25-*.txt` sono temporanei: eliminarli solo se non più necessari alla raccolta evidenze.

## Backup locali realizzati durante il laboratorio

- rp01: `/etc/haproxy/haproxy.cfg.ch25-pre-lb.bak`, `/etc/haproxy/haproxy.cfg.ch25-roundrobin-validated`, `/etc/haproxy/haproxy.cfg.ch25-leastconn-validated`, `/etc/haproxy/haproxy.cfg.ch25-pre-stats.bak`.
- A: `/etc/nginx/sites-available/ch23-ha.ch25-pre-slow.bak` (backup preesistente prima della modifica CGI).
- B: `/etc/nginx/sites-available/ch23-ha.ch25-pre-fibonacci.bak`.

Per tornare alla configurazione precedente, verificare il backup scelto e ripristinarlo con `cp -a` **solo dopo aver deciso quale checkpoint recuperare**; validare con `nginx -t` oppure `haproxy -c` prima di ricaricare. Non sostituire indiscriminatamente file appartenenti ai capitoli precedenti.

Il laboratorio del Capitolo 25 resta attivo dopo la semplice rimozione di `slow.bin`.
