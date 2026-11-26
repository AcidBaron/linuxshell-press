# R2 — Fencing reciproco dei due nodi Pacemaker tramite Hyper-V

**Data del test:** 26 novembre 2026. **Stato:** PASS per il fencing manuale richiesto tramite `stonith_admin`, failover e reinserimento; **fencing automatico non validato** (`stonith-enabled=false`).

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

Nel laboratorio il file R2 era già stato predisposto localmente sui due nodi e installato in `/usr/sbin/fence_hyperv_lab_r2`. La versione pubblicata è **ricostruita dal sorgente R1 disponibile su GitHub** con le modifiche R2 documentate; per stabilire l'identità byte per byte con i file locali occorre confrontare le checksum, prima di sostituirli.

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

**NON VALIDATO:** `stonith-enabled=true`, isolamento attivato automaticamente dopo fault/partizione, sicurezza in scenari di split-brain o guasto dell'host Hyper-V, resilienza a problemi SSH e rientro automatico dei servizi al boot. **Non attivare il fencing automatico sulla base del solo PASS manuale.**

## Sicurezza e rollback

Vedi [rollback R1/R2](../rollback/README.md). `Stop-VM -TurnOff` interrompe la VM bruscamente e può provocare perdita dati. Eseguire test distruttivi solo con supervisione, checkpoint coerenti e assenza di attività da preservare. Non pubblicare mai chiavi private, token o credenziali.
