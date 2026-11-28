# Procedura — Interpretare quorum, fencing e recupero nel cluster a due nodi

## VM da tenere accese

Host Windows Hyper-V con `LAB-LAN`; `fw01` (`10.77.0.1`), `infra01` (DNS, `10.77.0.10`), `dhcp01` (Kea, `10.77.0.30`), `linux-client01` (`10.77.0.101`), `dhcp-client01` (`10.77.0.150`). **`dhcp01` deve essere disponibile prima del nodo DHCP B**. Le altre VM del libro non servono.

Prerequisiti: cluster `ch23-cluster` completato nel Capitolo 23, risorse R2 per fencing reciproco e gruppo `ch23-web` (VIP `10.77.0.91` + Nginx) dell'Appendice C. I due nodi condividono l'host Hyper-V: questo non crea disponibilità rispetto al guasto dell'host fisico.

Se il cluster è fermo perché i servizi `corosync` e `pacemaker` sono stati lasciati `disabled` all'avvio (come nel laboratorio), da un nodo con entrambi raggiungibili:
```bash
sudo pcs cluster start --all
sudo pcs status
```
Non abilitare automaticamente i servizi al boot solo per seguire questa procedura. Non riattivare Nginx autonomamente via `systemctl enable`: la risorsa `systemd:nginx` è sotto controllo Pacemaker.

## 1. Quorum: leggere il risultato reale

Su **`linux-client01`**, Bash:
```bash
sudo corosync-quorumtool -s
sudo grep -A 12 'quorum {' /etc/corosync/corosync.conf
```

Risultato verificato:
```text
Nodes: 2
Quorate: Yes
Expected votes: 2
Total votes: 2
Quorum: 1
Flags: 2Node Quorate WaitForAll

quorum {
    provider: corosync_votequorum
    two_node: 1
}
```
`two_node: 1` è dichiarato esplicitamente; `wait_for_all` compare nei flag ma non è dichiarato separatamente nel file: è attivato dalla modalità a due nodi. I due nodi vengono attesi al primo raggiungimento del quorum; dopo la formazione iniziale del cluster, una partizione di un solo nodo può essere quorate. **Il quorum non dimostra che l'altro nodo sia stato spento**. Due partizioni quorate non possono essere lasciate a gestire indipendentemente risorse condivise: il fencing e i suoi requisiti di raggiungibilità sono centrali.

## 2. Configurazione del fencing

Su **`linux-client01`**:
```bash
sudo pcs property config
sudo pcs stonith config ch23-fence-linux
sudo pcs stonith config ch23-fence-dhcp
sudo pcs constraint config --full
```

Risultati verificati:
- `stonith-enabled=true`; `stonith-action=off`: l'azione di isolamento predefinita è lo spegnimento.
- `ch23-fence-linux` → `linux-client01`, con `pcmk_delay_base=15s`.
- `ch23-fence-dhcp` → `dhcp-client01`, senza parametro di ritardo aggiuntivo.
- Entrambi gli agenti sono `stonith:fence_hyperv_lab_r2`, usano SSH verso Hyper-V e monitoraggio ogni 60 s.
- Vincoli `-INFINITY`: il dispositivo che spegne `linux-client01` non può essere collocato su `linux-client01`; analogamente per `dhcp-client01`.
- **Non pubblicare** la chiave privata SSH indicata dal parametro `identity_file`.

La preferenza asimmetrica riduce la competizione in alcune partizioni, ma **non è una garanzia assoluta di assenza di split-brain**.

## 3. Risorse che condividono lo stesso nodo

Su **`linux-client01`**:
```bash
sudo pcs resource config ch23-web
sudo pcs status
```

Risultato osservato: gruppo `ch23-web` contenente, nell'ordine, `ch23-vip` (`ocf:heartbeat:IPaddr2`, `10.77.0.91/24`, `eth0`) e `ch23-nginx` (`systemd:nginx`). Entrambe monitorate ogni **10 secondi**; timeout start/stop VIP 20 s, Nginx 100 s. Il gruppo definisce ordine e collocazione **nel normale funzionamento coordinato**: non costituisce da solo una protezione contro partizioni indipendenti.

## 4. Guasto applicativo: arresto controllato di Nginx

Questa prova **è stata effettivamente eseguita** il 28/11. Prima di riprodurla controllare che `ch23-web` sia attivo e dove sia collocato; nell'esperimento era su `linux-client01`. Eseguire l'arresto **sul nodo che ospita Nginx**, non indifferentemente su uno dei due:

```bash
sudo systemctl stop nginx
sudo pcs status --full
```

Esito verificato: il monitor `ch23-nginx_monitor_10000` segnala `not running (7)`, `fail-count=1`, `migration-threshold=1000000`. Pacemaker **riavvia Nginx sullo stesso nodo**, mantenendo `ch23-vip` sul nodo e lasciando entrambi i membri Online. Nello stato osservato non è intervenuto il fencing; l'errore storico può restare nel report malgrado la risorsa sia nuovamente Started. **Non dedurre da questo test il tempo di recupero**, non misurato.

Dopo aver verificato il recupero:
```bash
sudo pcs resource cleanup ch23-nginx
sudo pcs status
```
**PASS osservato:** nessuna failed action residua, VIP e Nginx ancora sul nodo A, entrambi i nodi online. Il cleanup ha riportato messaggi riferiti anche alla VIP, appartenente allo stesso gruppo: il comando può rieseguire controlli collegati.

## 5. Distinguere il fencing automatico da un errore del servizio

Non ripetere la partizione di rete senza un piano di protezione e recupero. Lo scenario distruttivo è già stato verificato nel [laboratorio Hyper-V R2](../../laboratorio-fencing-esterno-hyperv/procedure/02-fencing-reciproco-r2.md) il 27/11.

Sul nodo A, il 28/11 è stato provato:
```bash
sudo stonith_admin --history='*'
```
Risultato: `0 events found`. Lo storico STONITH corrente non è per forza un archivio persistente: **non significa che il fencing precedente non sia avvenuto**.

Il recupero del journal ha invece avuto esito positivo:
```bash
sudo journalctl -u pacemaker \
  --since "2026-11-27 15:19:00" \
  --until "2026-11-27 15:23:00" \
  --no-pager
```

Sequenza documentata sul nodo A:
- **15:20:56**: il nodo B `dhcp-client01` scompare dalla membership; il DC precedente era B.
- **15:20:56**: lo scheduler dichiara B `unclean`, programma `Fence (off)` e il controller richiede il fencing.
- **15:20:58**: `pacemaker-fenced` registra `Operation 'off' ... using ch23-fence-dhcp returned 0`; il controller conferma la terminazione.
- **15:20:58**: `ch23-demo` viene avviata su A dopo la conferma dell'isolamento.

La richiesta proviene da `pacemaker-controld.1106`, **non** da una chiamata manuale a `stonith_admin`. Nell'evento il controller segnala anche `Cluster does not have watchdog fencing device`: è stato utilizzato il fencing Hyper-V esterno.

**Il tempo fra le righe del journal non è un benchmark generale di fencing**. I log hanno risoluzione di un secondo e il tempo dipende dal contesto.

## 6. Split-brain: il rischio, senza simulazione distruttiva

In una partizione di rete, due nodi possono smettere di comunicare pur continuando entrambi a eseguire i propri servizi. Con `two_node: 1`, il quorum a un voto non basta da solo a evitare decisioni indipendenti. Se entrambe le parti potessero rendere attiva la VIP o scrivere dati condivisi, potrebbero verificarsi collisioni di indirizzo e corruzione.

Un gruppo Pacemaker rende coerenti VIP e Nginx **all'interno della stessa vista del cluster**; non obbliga per magia una VM isolata a fermarsi. La protezione dipende dal completamento del fencing e dalla disponibilità del percorso SSH/Hyper-V. Il ritardo `pcmk_delay_base=15s` evita alcune corse ma non rappresenta una terza autorità di quorum. L'host Hyper-V unico rimane un singolo punto di guasto.

**Non eseguito:** simulazione di scritture concorrenti, partizione che impedisca anche il fencing, guasto dell'host Hyper-V e verifica di tutti i casi di avvio simultaneo. Trattarli come analisi dei rischi, non come PASS di laboratorio.

## 7. Checkpoint e recupero

Su **Windows PowerShell amministratore** sono stati eseguiti e verificati, il 28/11/2026:
```powershell
Checkpoint-VM -Name "linux-client01" `
    -SnapshotName "CH24-QUORUM-FENCING-VALIDATED"
Checkpoint-VM -Name "dhcp-client01" `
    -SnapshotName "CH24-QUORUM-FENCING-VALIDATED"

Get-VMSnapshot -VMName "linux-client01", "dhcp-client01" |
    Where-Object { $_.Name -eq "CH24-QUORUM-FENCING-VALIDATED" } |
    Select-Object VMName, Name, CreationTime
```

**Risultati osservati:** `linux-client01` alle 15:18:30 e `dhcp-client01` alle 15:18:33 (28/11/2026). Questi snapshot non formano un checkpoint distribuito atomico: **non ripristinare un solo nodo mentre il peer è in funzione**. Un ripristino va pianificato su entrambi i nodi con cluster fermo e stato dei dati verificato. Non costituiscono un backup di produzione.

## Stato finale atteso

Entrambi i nodi Online, quorum presente; `ch23-web` con VIP e Nginx sullo stesso nodo; `ch23-demo` su un nodo operativo; due dispositivi R2 Started sui rispettivi peer; dispositivo R1 disabilitato. Corosync e Pacemaker restano `active/disabled` al boot nell'ambiente di laboratorio, Nginx `disabled` da systemd e gestito dal cluster. Nessun nuovo test distruttivo necessario.
