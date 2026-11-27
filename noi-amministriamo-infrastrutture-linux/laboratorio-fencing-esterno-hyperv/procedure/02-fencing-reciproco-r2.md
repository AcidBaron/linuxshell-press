# R2 — Fencing reciproco dei due nodi Pacemaker tramite Hyper-V

**Date delle prove:** 26–27 novembre 2026. **Stato:** PASS per fencing manuale e recupero (26/11), e PASS per fencing automatico su perdita Corosync, failover e reinserimento (27/11). Il risultato automatico è specifico allo scenario verificato; non è una garanzia di comportamento in tutti i guasti.

Questa prova amplia la R1, che poteva gestire soltanto `web01`. La R2 consente **esclusivamente** `linux-client01` e `dhcp-client01`; impedisce quindi di usare accidentalmente `web01` con il nuovo agente. Le due VM sono sullo stesso Hyper-V, che resta un singolo punto di guasto. Non usare questa implementazione come modello di produzione senza verifiche aggiuntive.

## Topologia

| Elemento | Identità |
| --- | --- |
| Host Windows Hyper-V | `10.77.0.254`, account SSH `Utente` |
| Nodo A | `linux-client01`, `10.77.0.101` |
| Nodo B | `dhcp-client01`, `10.77.0.150` |
| Cluster | `ch23-cluster`, Pacemaker 2.1.6, PCS 0.11.7 |
| VIP | `10.77.0.91/24` su `eth0` |
| Chiave dedicata | `/home/labadmin/.ssh/id_ed25519_ch23_fencing` (presente localmente su ciascun nodo, **non** nel repository) |

L'agente invoca la libreria `fencing.py` installata dal sistema e usa SSH non interattivo per eseguire PowerShell con `Get-VM`, `Start-VM`, `Stop-VM -TurnOff`. Non prevede WinRM, JEA o servizi di controllo aggiuntivi.

## Codice e installazione

- Sorgente: [fence_hyperv_lab_R2.py](../src/fence_hyperv_lab_R2.py).
- Installazione su **entrambi** i nodi, conservando la R1 separatamente:

```bash
python3 -m py_compile ~/fence_hyperv_lab_R2.py
sudo install -o root -g root -m 755 ~/fence_hyperv_lab_R2.py /usr/sbin/fence_hyperv_lab_r2
```

Nel laboratorio il file R2 era già stato predisposto localmente sui due nodi e installato in `/usr/sbin/fence_hyperv_lab_r2`. **Verifica completata con gli export dei due nodi:** il file pubblicato su GitHub è identico byte per byte al file `/usr/sbin/fence_hyperv_lab_r2` su entrambe le VM (SHA-256 `d36eaf89877fa62af250618310aeee1772966812a88a7a6c011d2ed478a3bd67`). L'intestazione interna del codice continua a dire R1/web01: è un residuo puramente descrittivo della derivazione; il codice effettivo utilizza esclusivamente la allowlist R2. Si mantiene qui il file esatto collaudato.

```bash
sha256sum /usr/sbin/fence_hyperv_lab_r2
```

## Test di allowlist e stato (eseguiti)

- `--action=list`: `dhcp-client01` e `linux-client01`, exit 0.
- `--action=status --plug=web01`: rifiuto, exit 1.
- Dal nodo `linux-client01`: stato remoto di `dhcp-client01` = `Status: ON`, exit 0.
- Dal nodo `dhcp-client01`: stato remoto di `linux-client01` = `Status: ON`, exit 0.

Comando di esempio, **solo interrogazione**, su `dhcp-client01`:

```bash
sudo /usr/sbin/fence_hyperv_lab_r2 \
  --action=status --ip=10.77.0.254 --username=Utente \
  --ssh --plug=linux-client01 \
  --identity-file=/home/labadmin/.ssh/id_ed25519_ch23_fencing
```

## Risorse PCS effettivamente usate

La prima risorsa generica `ch23-fence-hyperv-r2` è stata eliminata prima del test. Sono state create due risorse dedicate, inizialmente disabilitate:

```bash
sudo pcs stonith create ch23-fence-linux \
  fence_hyperv_lab_r2 \
  ip=10.77.0.254 username=Utente ssh=1 \
  identity_file=/home/labadmin/.ssh/id_ed25519_ch23_fencing \
  plug=linux-client01 \
  pcmk_host_list=linux-client01 pcmk_host_check=static-list \
  --disabled

sudo pcs stonith create ch23-fence-dhcp \
  fence_hyperv_lab_r2 \
  ip=10.77.0.254 username=Utente ssh=1 \
  identity_file=/home/labadmin/.ssh/id_ed25519_ch23_fencing \
  plug=dhcp-client01 \
  pcmk_host_list=dhcp-client01 pcmk_host_check=static-list \
  --disabled

sudo pcs constraint location ch23-fence-linux avoids linux-client01
sudo pcs constraint location ch23-fence-dhcp avoids dhcp-client01

sudo pcs stonith enable ch23-fence-linux --wait=30
sudo pcs stonith enable ch23-fence-dhcp --wait=30
```

I vincoli `-INFINITY` sono stati verificati tramite `pcs constraint config --full`. Risultato:

| Agente | VM bersaglio | Nodo di esecuzione osservato |
| --- | --- | --- |
| `ch23-fence-linux` | `linux-client01` | `dhcp-client01` |
| `ch23-fence-dhcp` | `dhcp-client01` | `linux-client01` |

Il comando `stonith_admin --list=...` mostra i dispositivi disponibili **dal nodo interrogato**, e non costituisce da solo una verifica globale: dal nodo B veniva elencato `ch23-fence-linux` per A, e da A veniva elencato `ch23-fence-dhcp` per B.

## Fencing reale, failover e reinserimento — evidenze

Prima del test Corosync riportava: 2 nodi, `Quorate: Yes`, `Expected votes: 2`, `Quorum: 1`, flag `2Node Quorate WaitForAll`.

Da **`dhcp-client01`** è stato eseguito:

```bash
sudo stonith_admin --fence=linux-client01 --timeout=60
echo "EXIT CODE: $?"
sudo pcs status
```

**Esito fencing:** `EXIT CODE: 0`.

Stato osservato subito dopo:

- `dhcp-client01` online, DC e partizione con quorum.
- `linux-client01` offline; sessione SSH persa come conseguenza dello spegnimento.
- `ch23-demo` Started su `dhcp-client01`.
- `ch23-vip` Started su `dhcp-client01`.
- `ip -4 -br addr show dev eth0` su B mostrava fisicamente `10.77.0.150/24` e `10.77.0.91/24`.
- `ch23-fence-linux` Started su B; `ch23-fence-dhcp` Stopped mentre A era spento.

Poi, dalla console Windows:

```powershell
Start-VM -Name "linux-client01"
Get-VM -Name "linux-client01" | Select-Object Name, State
```

Risultato `linux-client01 Running`. Il nodo **non** è rientrato automaticamente nel cluster perché, nel laboratorio, `corosync` e `pacemaker` sono `active/disabled`. Dopo il collegamento SSH a `linux-client01`:

```bash
sudo pcs cluster start
sudo pcs status
```

Esito finale: **entrambi online**; `ch23-demo` Started su `dhcp-client01`; `ch23-vip` nuovamente Started su `linux-client01`; `ch23-fence-linux` Started su B; `ch23-fence-dhcp` Started su A. La ricollocazione della VIP è stata osservata in `pcs status` dopo il rientro, senza modifica manuale.

## Cosa è PASS e cosa non è stato provato

**PASS:** agente R2 su entrambi i nodi, allowlist, comandi di stato SSH/Hyper-V, due risorse STONITH separate, vincoli reciproci, fencing **manuale** di A richiesto da B, quorum superstite, VIP visibile sull'interfaccia B dopo failover, riaccensione di A, rientro nel cluster e ripristino di entrambe le risorse STONITH.

**PASS aggiuntivo (27/11):** attivazione di `stonith-enabled=true`, fencing automatico di `dhcp-client01` dopo isolamento del traffico Corosync su UDP 5405, spegnimento confermato da Windows Hyper-V e successivo reinserimento del nodo. **NON VALIDATO:** sicurezza generalizzata contro split-brain, guasto dell'host Hyper-V, altri tipi di partizione, resilienza a problemi SSH e rientro automatico dei servizi al boot. Non replicare su macchine che ospitano dati o servizi indispensabili.

## Sicurezza e rollback

Vedi [rollback R1/R2](../rollback/README.md). `Stop-VM -TurnOff` interrompe la VM bruscamente e può provocare perdita dati. Eseguire test distruttivi solo con supervisione, checkpoint coerenti e assenza di attività da preservare. Non pubblicare mai chiavi private, token o credenziali.


## Prova di fencing automatico — 27 novembre 2026 (PASS)

**Prerequisito emerso nella ripresa:** `dhcp-client01` dipende dal server DHCP `dhcp01`. Quando `dhcp01` era spento, `pcs cluster start --all` non raggiungeva B sulla porta TCP 2224. Avviato `dhcp01` e ottenuto l'indirizzo `10.77.0.150`, il cluster era nuovamente Online sui due nodi. Il laboratorio richiede dunque `dhcp01` acceso dall'inizio, oltre a host Hyper-V, `linux-client01`, `dhcp-client01` e servizi di infrastruttura necessari.

### Preparazione controllata

Da `linux-client01`:
```bash
sudo pcs property set stonith-action=off
sudo pcs stonith update ch23-fence-linux pcmk_delay_base=15s
sudo pcs property set stonith-enabled=true
sudo pcs status
sudo corosync-cfgtool -s
```

Il cluster mostrava entrambi i nodi online, quorum, entrambe le risorse STONITH R2 Started sui peer opposti; il collegamento Corosync `knet` era connesso su `10.77.0.101`. Il valore `pcmk_delay_base=15s` su `ch23-fence-linux` rende più tardivo il tentativo di spegnere A, favorendo A in caso di contesa; **non elimina ogni rischio di fencing reciproco**.

Su `dhcp-client01` è stato installato il file **temporaneo** `/usr/local/sbin/ch23-corosync-heal.sh`:

```bash
sudo tee /usr/local/sbin/ch23-corosync-heal.sh >/dev/null <<'EOF'
#!/bin/bash
iptables -D INPUT -s 10.77.0.101 \
  -p udp --dport 5405 -j DROP 2>/dev/null || true
iptables -D OUTPUT -d 10.77.0.101 \
  -p udp --dport 5405 -j DROP 2>/dev/null || true
EOF
sudo chmod 700 /usr/local/sbin/ch23-corosync-heal.sh
sudo bash -n /usr/local/sbin/ch23-corosync-heal.sh
```

La prova è stata eseguita con console Hyper-V disponibili e senza attività da preservare sulla VM bersaglio. Il timer non può funzionare durante lo spegnimento della VM: **non va considerato una protezione sufficiente per un test distruttivo**.

### Simulazione della perdita del collegamento Corosync

Su `dhcp-client01`, in una sola sessione:
```bash
sudo bash <<'EOF'
set -e
systemd-run --unit=ch23-corosync-heal-r2 --on-active=120s \
  /usr/local/sbin/ch23-corosync-heal.sh
iptables -w -I INPUT -s 10.77.0.101 -p udp --dport 5405 -j DROP
iptables -w -I OUTPUT -d 10.77.0.101 -p udp --dport 5405 -j DROP
echo "CH23: isolamento Corosync applicato"
EOF
```

Risultato: timer creato, `CH23: isolamento Corosync applicato`.

Sul nodo superstite A, `sudo pcs status --full` ha mostrato:

```text
Current DC: linux-client01 (1) - partition with quorum
Node dhcp-client01 (2): OFFLINE
Node linux-client01 (1): online
ch23-demo: Started linux-client01
ch23-vip: Started linux-client01
ch23-fence-linux: Stopped
ch23-fence-dhcp: Started linux-client01

Fencing History:
turning off of dhcp-client01 successful:
delegate=linux-client01, client=pacemaker-controld.1106,
origin=linux-client01, completed='2026-11-27 15:20:58.421676Z'
```

**Osservazione determinante:** `client=pacemaker-controld`, non `stonith_admin`. Il fencing è stato avviato automaticamente dal controller Pacemaker in risposta all'isolamento di B.

Verifica indipendente in Windows PowerShell:
```powershell
Get-VM -Name "linux-client01", "dhcp-client01" |
  Select-Object Name, State
```
Risultato osservato: `linux-client01 Running`; `dhcp-client01 Off`.

### Recupero dopo il fencing

Da Windows:
```powershell
Start-VM -Name "dhcp-client01"
Get-VM -Name "dhcp-client01" | Select-Object Name, State
```
Risultato: `dhcp-client01 Running`. Dopo il rientro in cluster, `sudo pcs status` eseguito su B ha mostrato entrambi i nodi **Online**, quorum, `ch23-demo` Started su A, `ch23-vip` Started su B, `ch23-fence-linux` Started su B e `ch23-fence-dhcp` Started su A.

**Stato finale osservato:** `stonith-enabled=true`, `stonith-action=off`, `pcmk_delay_base=15s` su `ch23-fence-linux`; timer e regole di test erano temporanei. Prima di considerare conclusa la pulizia del laboratorio, controllare l'assenza di eventuali regole residue e dei timer di test. Il risultato con `stonith-enabled=true` resta sperimentale e non deve essere esteso a infrastrutture produttive.
