# Laboratorio parallelo — Realizzare un dispositivo di fencing esterno

Prototipo **R1** sperimentale per *Noi Amministriamo Infrastrutture Linux*, costruito il **26 novembre 2026**. Utilizza una VM Ubuntu per inviare, tramite SSH con chiave, comandi PowerShell all'host Windows Hyper-V. Riusando la libreria Python `fencing.py` del pacchetto `fence-agents`, fornisce un semplice agente riconosciuto da PCS/Pacemaker.

**Non è un fence agent per produzione.** R1 controlla deliberatamente **solo `web01`** e non può isolare i nodi `linux-client01` e `dhcp-client01`. Non equivale al fencing HA sicuro del cluster.

## Architettura verificata

`Pacemaker / stonith_admin → fence_hyperv_lab → SSH con chiave → PowerShell → Hyper-V → web01`

- Host Hyper-V LAB-LAN: `10.77.0.254`; OpenSSH Windows già attivo.
- Agente installato su `linux-client01` e `dhcp-client01`; `fencing.py` versione 4.12.1 installata tramite pacchetti di sistema.
- Una chiave ED25519 distinta per nodo, **non pubblicata**.
- Account Windows esistente (`Utente` nell'ambiente di prova); nessun account nuovo, nessun WinRM o JEA.
- Controllo R1: `web01` soltanto. **Attenzione:** `web01` è anche il backend Nextcloud del Capitolo 22; le prove di `off` sono appropriate solo quando è volontariamente sacrificabile e non eroga un servizio richiesto.

## File

- [Agente collaudato R1](src/fence_hyperv_lab_R1.py)
- [Installazione, test e integrazione PCS](procedure/01-installazione-e-test.md)
- [Limiti operativi e recupero](rollback/README.md)

SHA-256 del sorgente R1: `f590a6c8c0bd57b2b0cd90975a2b4807886ee1c57b3ebdad7f068ff4bee0d44d`.

## Evidenze del 26/11/2026

- Entrambi i nodi: SSH senza password, script Bash preliminare `status/on/off`.
- Agente Python: `metadata`, `status` (OFF = exit 2), `on` (0), `off` (0), `list` (0), `monitor` (0).
- `sudo pcs stonith describe fence_hyperv_lab` riconosce il dispositivo su entrambi i nodi.
- Risorsa PCS `ch23-fence-hyperv-lab` prima registrata `Stopped (disabled)`, poi avviata su `dhcp-client01`.
- `sudo stonith_admin --list=web01`: `1 fence device found`.
- Con `web01` accesa, `sudo stonith_admin --fence=web01 --timeout=60`: exit 0; successiva verifica Hyper-V: `Off`.
- La proprietà di cluster `stonith-enabled=false` è stata mantenuta: non è stata validata alcuna ripresa dopo guasto reale di un nodo del cluster.

## Pubblicazione e attribuzione

Il sorgente del prototipo è distribuito secondo la [GPL-3.0 del repository](../../LICENSE). Utilizza la **libreria di sistema** `fencing.py` del progetto open source fence-agents, senza includerne una copia modificata. Il modello architetturale è stato studiato da `fence_virsh`. Conservare i copyright e le licenze dei componenti upstream nelle rispettive distribuzioni.

Questa è una pubblicazione di un **prototipo didattico sperimentale**, non un'affermazione che non esistano altri agenti Hyper-V né una certificazione per l'uso in produzione.
