# Audit export configurazioni R1/R2 — 26 novembre 2026

**Origine:** archivio fornito dall'operatore `CH23_FENCING_R2_CONFIG_EXPORT.zip`, contenente `ch23-linux-client01-export.tar.gz` e `ch23-dhcp-client01-export.tar.gz`. Ogni archivio interno contiene nove file. I dati sono stati esaminati; il pacchetto grezzo **non** è stato pubblicato nel repository. Non erano incluse chiavi SSH private, `/etc/corosync/authkey` o esportazioni di credenziali di PCS.

## Confronto tra nodi

| File | Confronto |
| --- | --- |
| `corosync.conf` | Identico |
| `pcs-config.txt` | Identico |
| `pcs-status.txt` | Diverso: osservazioni locali dell'output runtime |
| `stonith.txt` | Identico |
| `constraints.txt` | Identico |
| `properties.txt` | Identico |
| `fence_hyperv_lab` (R1) | Identico |
| `fence_hyperv_lab_r2` (R2) | Identico |
| `sha256-agents.txt` | Identico |

### SHA-256 degli agenti

| Agente | SHA-256 verificato su entrambi i nodi |
| --- | --- |
| R1 (`/usr/sbin/fence_hyperv_lab`) | `f590a6c8c0bd57b2b0cd90975a2b4807886ee1c57b3ebdad7f068ff4bee0d44d` |
| R2 (`/usr/sbin/fence_hyperv_lab_r2`) | `d36eaf89877fa62af250618310aeee1772966812a88a7a6c011d2ed478a3bd67` |

Dopo l'audit la versione pubblicata di `src/fence_hyperv_lab_R2.py` è stata sostituita con il contenuto esatto del file installato, senza modifiche funzionali o cosmetiche. Blob SHA Git verificato: `e1e169e5f5a251433783982bcfa3e2cc95e5f4ce`. Il commento iniziale menziona ancora “R1” e “web01”, benché la allowlist operativa includa **solo** `linux-client01` e `dhcp-client01`. Si tratta di un'anomalia **documentale** del sorgente validato, non di un allargamento dei bersagli autorizzati; modificarla creerebbe una nuova versione da riconfrontare.

## Cluster e risorse

- `corosync.conf`: cluster `ch23-cluster`, trasporto `knet`, `crypto_cipher: aes256`, `crypto_hash: sha256`, nodi `linux-client01` (ID 1, `10.77.0.101`) e `dhcp-client01` (ID 2, `10.77.0.150`), `two_node: 1`.
- Proprietà Pacemaker: `stonith-enabled=false`; nessun watchdog registrato (`have-watchdog=false`).
- Risorse applicative: `ch23-demo` (Dummy) avviata su `dhcp-client01`; `ch23-vip` (IPaddr2, `10.77.0.91/24`, `eth0`) avviata su `linux-client01` nel rilevamento finale.
- R1 `ch23-fence-hyperv-lab`: `target-role=Stopped`, bersaglio `web01`.
- R2 `ch23-fence-linux`: bersaglio `linux-client01`, avviata su `dhcp-client01`, vincolo `avoids linux-client01` con `-INFINITY`.
- R2 `ch23-fence-dhcp`: bersaglio `dhcp-client01`, avviata su `linux-client01`, vincolo `avoids dhcp-client01` con `-INFINITY`.
- Per entrambi gli agenti R2: `ip=10.77.0.254`, `username=Utente`, `ssh=1`, `identity_file=/home/labadmin/.ssh/id_ed25519_ch23_fencing`, `pcmk_host_check=static-list`, `plug` e `pcmk_host_list` specifici per bersaglio.

`pcs status --full` su entrambi i nodi riporta cluster con quorum, due nodi online e agenti collocati correttamente. Servizi: `corosync` e `pacemaker` `active/disabled`, `pcsd` `active/enabled`.

## Evidenza storica del fencing

In `Fencing History` di `pcs status --full` è registrato:

- `turning off of linux-client01 successful`, `delegate=dhcp-client01`, `client=stonith_admin.10001`, `origin=dhcp-client01`, completato il **26/11/2026 alle 18:53:34.830366 UTC**.
- `turning off of web01 successful`, `delegate=dhcp-client01`, `client=stonith_admin.29743`, `origin=linux-client01`, completato il **26/11/2026 alle 18:24:51.831223 UTC**.

Si tratta di **fencing richiesti manualmente tramite `stonith_admin`**, non di iniziative automatiche del cluster. Il recupero della VIP e il riavvio della VM sono registrati nella [procedura R2](02-fencing-reciproco-r2.md) attraverso gli output osservati durante il test.

## Conclusioni e confini dell'audit

**PASS:** allineamento dei file di configurazione tra nodi, conservazione R1, corrispondenza byte per byte della R2 pubblicata e della R2 installata, configurazione di due bersagli separati, conferma dello spegnimento riuscito nella cronologia.

**Non verificato da questo export:** chiavi/ACL di Windows, correttezza delle ACL sul filesystem Linux, persistenza di una VIP solo tramite `pcs status` (la sua presenza reale su `eth0` di B era stata osservata separatamente durante il failover), quorum in presenza di partizioni simmetriche, fencing automatico, host Hyper-V offline, protezione del dispositivo da self-fencing in condizioni di perdita della membership e comportamento in scenari di guasto multiplo.

Gli export contengono indirizzi e nomi interni: evitare di pubblicare indiscriminatamente gli archivi originali. Il rollback del laboratorio deve essere coordinato e non prevede il ripristino indipendente dei due checkpoint mentre il cluster è attivo.
