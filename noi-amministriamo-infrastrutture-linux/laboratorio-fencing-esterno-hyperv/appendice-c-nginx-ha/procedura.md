# Appendice C — Nginx in alta disponibilità con Pacemaker

**Prova del 28 novembre 2026: PASS per failover controllato e ripristino.** Il sito è stato verificato da Firefox su Windows tramite VIP prima e dopo il trasferimento. **Non** sono stati misurati tempi di indisponibilità né simulato un guasto improvviso del nodo per questo specifico gruppo web.

## Macchine e servizi
- Nodo A `linux-client01` (`10.77.0.101`), nodo B `dhcp-client01` (`10.77.0.150`).
- `dhcp01` (`10.77.0.30`) **deve essere acceso**, perché B dipende dal servizio DHCP. Tenere disponibili anche host Hyper-V, infrastruttura DNS e gateway secondo il laboratorio.
- Cluster `ch23-cluster`, Corosync/Pacemaker già configurati; dispositivi STONITH R2 già verificati. Nessuna nuova VM.
- VIP esistente `ch23-vip`: `10.77.0.91/24`, agente `ocf:heartbeat:IPaddr2`, dispositivo `eth0`.
- Nginx è gestito da Pacemaker con `systemd:nginx`; `systemctl disable --now nginx` su entrambi evita avvio autonomo.

## 1. Installare Nginx e il sito su ciascun nodo

Eseguire separatamente su **entrambi** i nodi, dopo `sudo ss -ltnp '( sport = :80 )'` e verifica che la porta non sia occupata:

```bash
sudo apt update
sudo apt install -y nginx
sudo systemctl disable --now nginx
sudo mkdir -p /var/www/ch23-ha
```

Scaricare dal repository [www/index.html](www/index.html) e [nginx/ch23-ha.conf](nginx/ch23-ha.conf) oppure crearli con i rispettivi contenuti pubblicati:

```bash
BASE=https://raw.githubusercontent.com/AcidBaron/linuxshell-press/main/noi-amministriamo-infrastrutture-linux/laboratorio-fencing-esterno-hyperv/appendice-c-nginx-ha
sudo curl -fL "$BASE/www/index.html" -o /var/www/ch23-ha/index.html
sudo curl -fL "$BASE/nginx/ch23-ha.conf" -o /etc/nginx/sites-available/ch23-ha
sudo ln -s /etc/nginx/sites-available/ch23-ha /etc/nginx/sites-enabled/ch23-ha
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
```

**Nota editoriale:** nel laboratorio effettivo i due file sono stati creati con `tee`/reindirizzamento e poi validati. I due comandi `curl` riproducono gli stessi contenuti, ma **non sono stati eseguiti nella prova originale**.

La verifica locale è stata effettuata con:
```bash
sudo systemctl start nginx
curl -fsS http://127.0.0.1/
sudo systemctl stop nginx
```
**Esito osservato:** HTML completo su A e B, con titolo «Linuxshell Press - HA».

## 2. Registrare e raggruppare le risorse

Da **`linux-client01`**, con entrambi i nodi online e quorum:
```bash
sudo pcs status
sudo pcs resource create ch23-nginx systemd:nginx op monitor interval=10s --disabled
sudo pcs resource group add ch23-web ch23-vip ch23-nginx
sudo pcs status
sudo pcs resource enable ch23-nginx --wait=30
sudo pcs status
```

**Esito osservato:** gruppo `ch23-web`, VIP e Nginx entrambi `Started linux-client01`; il dummy `ch23-demo` resta indipendente. Il gruppo impone co-locazione e ordine di avvio (prima VIP, poi Nginx). I due agenti STONITH R2 restano disponibili sui rispettivi peer.

## 3. Verifica applicativa prima del failover

Dal PC Windows in Firefox aprire `http://10.77.0.91/`.

**PASS osservato:** la pagina visualizza «Servizio web in alta disponibilità» e «Cluster Pacemaker/Corosync - Linuxshell Press».

## 4. Failover controllato

Su **`linux-client01`**:
```bash
sudo pcs node standby linux-client01
sudo pcs status
```

Il primo `pcs status` è stato letto durante il trasferimento: A in `standby (with active resources)`, Nginx `Stopping` su A, VIP ancora su A. Non scambiare uno stato transitorio per un errore definitivo.

Dopo la conclusione della transizione:
```bash
sudo pcs status
```

**PASS osservato:** A in `standby`, B online con quorum, `ch23-vip` e `ch23-nginx` entrambi `Started dhcp-client01`. Da Firefox sul PC Windows, `http://10.77.0.91/` mostrava nuovamente la stessa pagina.

**Attenzione al fencing:** durante lo standby di A, `ch23-fence-dhcp` risultava `Stopped` perché quel dispositivo viene collocato sul nodo A; quindi in questa fase non era garantito il fencing reciproco completo. Il test è un **trasferimento controllato**, non una validazione della sicurezza contro tutti i guasti.

## 5. Uscita dallo standby e ripristino

Su `linux-client01`:
```bash
sudo pcs node unstandby linux-client01
sudo pcs status
```

**PASS osservato:** entrambi i nodi Online, quorum, gruppo `ch23-web` (VIP + Nginx) nuovamente su `linux-client01`; `ch23-demo` su `dhcp-client01`, `ch23-fence-linux` su B, `ch23-fence-dhcp` su A; R1 disabilitata.

## Limiti e rollback

- Non sono stati eseguiti test distruttivi del gruppo web né misure di downtime; il browser è stato controllato **a trasferimento terminato**.
- Un sito statico copiato su entrambi i nodi non richiede replica dati. Per Nextcloud, database, sessioni e file degli utenti richiederebbero un progetto HA distinto.
- In caso di prova interrotta durante lo standby, prima verificare `sudo pcs status` e poi, se appropriato, `sudo pcs node unstandby linux-client01`.
- Per dismettere la dimostrazione senza eliminare la VIP esistente, pianificare il distacco ordinato di `ch23-nginx` dal gruppo e la sua eliminazione, verificando prima lo stato e i vincoli. **Nessun rollback distruttivo è stato eseguito** nella prova: non presentare una sequenza di rimozione non testata come PASS.
