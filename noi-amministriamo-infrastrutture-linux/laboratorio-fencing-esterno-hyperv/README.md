# Laboratorio parallelo — Realizzare un dispositivo di fencing esterno

Prototipi **R1 e R2** sperimentali per *Noi Amministriamo Infrastrutture Linux*, costruito il **26 novembre 2026**. Utilizza una VM Ubuntu per inviare, tramite SSH con chiave, comandi PowerShell all'host Windows Hyper-V. Riusando la libreria Python `fencing.py` del pacchetto `fence-agents`, fornisce un semplice agente riconosciuto da PCS/Pacemaker.

**Non sono fence agent per produzione.** R1 controlla deliberatamente **solo `web01`**; R2 è limitato ai due nodi `linux-client01` e `dhcp-client01`. R2 ha superato sia la prova di fencing **manuale** (26/11/2026) sia una prova di fencing **automatico** su perdita del collegamento Corosync (27/11/2026), con recupero del nodo. Rimane un prototipo didattico non adatto alla produzione.

## Architettura verificata

`Pacemaker / stonith_admin → fence_hyperv_lab (R1) oppure fence_hyperv_lab_r2 (R2) → SSH con chiave → PowerShell → Hyper-V → VM nella allowlist`

- Host Hyper-V LAB-LAN: `10.77.0.254`; OpenSSH Windows già attivo.
- Agente installato su `linux-client01` e `dhcp-client01`; `fencing.py` versione 4.12.1 installata tramite pacchetti di sistema.
- Una chiave ED25519 distinta per nodo, **non pubblicata**.
- Account Windows esistente (`Utente` nell'ambiente di prova); nessun account nuovo, nessun WinRM o JEA.
- Controllo R1: `web01` soltanto. R2: `linux-client01` e `dhcp-client01` soltanto. **Attenzione:** `web01` è anche il backend Nextcloud del Capitolo 22; le prove di `off` sono appropriate solo quando è volontariamente sacrificabile e non eroga un servizio richiesto.

## File

- [Agente collaudato R1](src/fence_hyperv_lab_R1.py)
- [Agente sperimentale R2](src/fence_hyperv_lab_R2.py) — identico al sorgente installato su entrambi i nodi, verificato con SHA-256
- [Installazione, test e integrazione PCS — R1](procedure/01-installazione-e-test.md)
- [Fencing reciproco, failover e recupero — R2](procedure/02-fencing-reciproco-r2.md)
- [Script di ripristino delle regole Corosync per la prova automatica](linux/ch23-corosync-heal.sh)
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

Audit dei due export: `fence_hyperv_lab_r2` SHA-256 `d36eaf89877fa62af250618310aeee1772966812a88a7a6c011d2ed478a3bd67` su entrambi; sorgente GitHub identico per contenuto (blob Git `e1e169e5f5a251433783982bcfa3e2cc95e5f4ce`). Tutti i file di configurazione, tranne le istantanee di stato di PCS, hanno hash identico sui due nodi. [Audit completo](procedure/03-audit-export-r2.md).


- Installazione separata sui due nodi come `fence_hyperv_lab_r2`; allowlist dei soli due nodi.
- Due risorse STONITH con collocazione reciproca: `ch23-fence-linux` avviata su `dhcp-client01`, `ch23-fence-dhcp` su `linux-client01`; vecchia R1 disabilitata.
- Test manuale `stonith_admin --fence=linux-client01 --timeout=60` da `dhcp-client01`: **exit 0**, nodo A offline.
- Il nodo superstite ha mantenuto quorum e acquisito `ch23-vip` (`10.77.0.91/24` effettivamente osservata su `eth0`).
- Dopo `Start-VM` su Hyper-V e `pcs cluster start` su A: entrambi i nodi online e VIP ritornata su A.
- Nel test manuale del 26/11 `stonith-enabled=false` è stato mantenuto. **Il 27/11** è stato abilitato `stonith-enabled=true` e validato un caso di fencing automatico. Vedi [procedura e risultati R2](procedure/02-fencing-reciproco-r2.md).

## Evidenze R2 del 27/11/2026 — fencing automatico

- Cluster a due nodi avviato con entrambi online e quorum; inizialmente il nodo `dhcp-client01` non aveva ottenuto DHCP perché `dhcp01` era spento. **`dhcp01` è un prerequisito operativo** per questo ambiente.
- `stonith-action=off`, `stonith-enabled=true`, `stonith-timeout=60s`; impostato `pcmk_delay_base=15s` su `ch23-fence-linux` per favorire `linux-client01` durante una partizione. Il ritardo non è garanzia universale.
- Interrotto solo il traffico UDP 5405 (Corosync/knet) da/verso `linux-client01` su `dhcp-client01` tramite due regole iptables temporanee. Previsto un timer di ripristino, non efficace durante lo spegnimento.
- **Fencing History:** `turning off of dhcp-client01 successful`, `delegate=linux-client01`, `client=pacemaker-controld.1106`, `origin=linux-client01`, `completed='2026-11-27 15:20:58.421676Z'`. Evidenza di decisione **automatica**, senza `stonith_admin` manuale.
- Windows Hyper-V: `linux-client01 Running`, `dhcp-client01 Off`; con nodo B isolato e spento, `ch23-demo` si è avviata su A e la VIP è rimasta su A.
- Dopo `Start-VM -Name "dhcp-client01"` e reinserimento: entrambi online, DC `linux-client01`, risorse R2 correttamente collocate; `ch23-demo` su A e VIP su B.
- **Limite:** è stata validata questa singola simulazione di perdita Corosync, non un insieme esaustivo di failure modes o scenari di split-brain.

## Pubblicazione e attribuzione

Il sorgente del prototipo è distribuito secondo la [GPL-3.0 del repository](../../LICENSE). Utilizza la **libreria di sistema** `fencing.py` del progetto open source fence-agents, senza includerne una copia modificata. Il modello architetturale è stato studiato da `fence_virsh`. Conservare i copyright e le licenze dei componenti upstream nelle rispettive distribuzioni.

Questa è una pubblicazione di un **prototipo didattico sperimentale**, non un'affermazione che non esistano altri agenti Hyper-V né una certificazione per l'uso in produzione.

## Appendice C — Servizio web Nginx in alta disponibilità (28/11/2026)

**PASS per failover controllato**, senza simulare uno spegnimento improvviso: gruppo `ch23-web` con `ch23-vip` e `ch23-nginx` attivo su A, trasferito dopo `pcs node standby linux-client01` su B, pagina HTTP verificata da Firefox tramite `10.77.0.91`, poi `pcs node unstandby linux-client01` con ritorno del gruppo su A e ripristino delle risorse STONITH R2. Non sono stati misurati tempi di indisponibilità.

- [Procedura operativa, risultati e limiti](appendice-c-nginx-ha/procedura.md)
- [Virtual host Nginx](appendice-c-nginx-ha/nginx/ch23-ha.conf)
- [Pagina HTML del test](appendice-c-nginx-ha/www/index.html)

Per la parte editoriale, i file di circa una pagina o meno possono essere riportati integralmente nel testo; file più lunghi restano nel repository con istruzioni di download, installazione e verifica.
