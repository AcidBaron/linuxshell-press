# Laboratorio parallelo — Realizzare un dispositivo di fencing esterno

Prototipi **R1 e R2** sperimentali per *Noi Amministriamo Infrastrutture Linux*, costruito il **26 novembre 2026**. Utilizza una VM Ubuntu per inviare, tramite SSH con chiave, comandi PowerShell all'host Windows Hyper-V. Riusando la libreria Python `fencing.py` del pacchetto `fence-agents`, fornisce un semplice agente riconosciuto da PCS/Pacemaker.

**Non sono fence agent per produzione.** R1 controlla deliberatamente **solo `web01`**; R2 è limitato ai due nodi `linux-client01` e `dhcp-client01`. R2 ha superato una prova reale di fencing **manuale**, failover della VIP e reinserimento, ma non è stato validato il fencing automatico (`stonith-enabled=false`).

## Architettura verificata

`Pacemaker / stonith_admin → fence_hyperv_lab (R1) oppure fence_hyperv_lab_r2 (R2) → SSH con chiave → PowerShell → Hyper-V → VM nella allowlist`

- Host Hyper-V LAB-LAN: `10.77.0.254`; OpenSSH Windows già attivo.
- Agente installato su `linux-client01` e `dhcp-client01`; `fencing.py` versione 4.12.1 installata tramite pacchetti di sistema.
- Una chiave ED25519 distinta per nodo, **non pubblicata**.
- Account Windows esistente (`Utente` nell'ambiente di prova); nessun account nuovo, nessun WinRM o JEA.
- Controllo R1: `web01` soltanto. R2: `linux-client01` e `dhcp-client01` soltanto. **Attenzione:** `web01` è anche il backend Nextcloud del Capitolo 22; le prove di `off` sono appropriate solo quando è volontariamente sacrificabile e non eroga un servizio richiesto.

## File

- [Agente collaudato R1](src/fence_hyperv_lab_R1.py)
- [Agente sperimentale R2](src/fence_hyperv_lab_R2.py) — codice ricostruito da R1 e modifiche R2; checksum da confrontare con i file installati
- [Installazione, test e integrazione PCS — R1](procedure/01-installazione-e-test.md)
- [Fencing reciproco, failover e recupero — R2](procedure/02-fencing-reciproco-r2.md)
- [Limiti operativi e recupero](rollback/README.md)

SHA-256 del sorgente R1: `f590a6c8c0bd57b2b0cd90975a2b4807886ee1c57b3ebdad7f068ff4bee0d44d`.

## Evidenze del 26/11/2026

- Entrambi i nodi: SSH senza password, script Bash preliminare `status/on/off`.
- Agente Python: `metadata`, `status` (OFF = exit 2), `on` (0), `off` (0), `list` (0), `monitor` (0).
- `sudo pcs stonith describe fence_hyperv_lab` riconosce il dispositivo su entrambi i nodi.
- Risorsa PCS `ch23-fence-hyperv-lab` prima registrata `Stopped (disabled)`, poi avviata su `dhcp-client01`.
- `sudo stonith_admin --list=web01`: `1 fence device found`.
- Con `web01` accesa, `sudo stonith_admin --fence=web01 --timeout=60`: exit 0; successiva verifica Hyper-V: `Off`.
- Durante R1 la proprietà `stonith-enabled=false` è stata mantenuta; nessuna ripresa dei nodi del cluster era stata provata a quel punto.

## Evidenze R2 del 26/11/2026

- Installazione separata sui due nodi come `fence_hyperv_lab_r2`; allowlist dei soli due nodi.
- Due risorse STONITH con collocazione reciproca: `ch23-fence-linux` avviata su `dhcp-client01`, `ch23-fence-dhcp` su `linux-client01`; vecchia R1 disabilitata.
- Test manuale `stonith_admin --fence=linux-client01 --timeout=60` da `dhcp-client01`: **exit 0**, nodo A offline.
- Il nodo superstite ha mantenuto quorum e acquisito `ch23-vip` (`10.77.0.91/24` effettivamente osservata su `eth0`).
- Dopo `Start-VM` su Hyper-V e `pcs cluster start` su A: entrambi i nodi online e VIP ritornata su A.
- `stonith-enabled=false` **non modificato**: la gestione automatica dei fault non è ancora dimostrata.

## Pubblicazione e attribuzione

Il sorgente del prototipo è distribuito secondo la [GPL-3.0 del repository](../../LICENSE). Utilizza la **libreria di sistema** `fencing.py` del progetto open source fence-agents, senza includerne una copia modificata. Il modello architetturale è stato studiato da `fence_virsh`. Conservare i copyright e le licenze dei componenti upstream nelle rispettive distribuzioni.

Questa è una pubblicazione di un **prototipo didattico sperimentale**, non un'affermazione che non esistano altri agenti Hyper-V né una certificazione per l'uso in produzione.
