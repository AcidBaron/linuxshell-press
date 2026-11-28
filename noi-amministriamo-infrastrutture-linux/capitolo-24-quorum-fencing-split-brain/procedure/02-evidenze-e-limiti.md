# Evidenze del Capitolo 24 — Provenienza e limiti

Tutte le prove sono state condotte sul laboratorio `ch23-cluster` con due VM su un unico Hyper-V.

| Data | Verifica | Esito |
| --- | --- | --- |
| 27/11/2026 | Fencing automatico dopo perdita comunicazione Corosync, agente R2 | PASS osservato: B spento da Hyper-V, risorsa `ch23-demo` recuperata su A |
| 28/11/2026 | `corosync-quorumtool -s` + `corosync.conf` | PASS: due voti, quorum 1, `2Node Quorate WaitForAll`, `two_node: 1` |
| 28/11/2026 | Proprietà STONITH, agenti e vincoli | PASS: `stonith-enabled=true`, `stonith-action=off`, ritardo 15 s verso A, vincoli -INFINITY |
| 28/11/2026 | Configurazione del gruppo `ch23-web` | PASS: VIP e Nginx monitorati ogni 10 s, collocazione di gruppo |
| 28/11/2026 | `systemctl stop nginx` sul nodo attivo | PASS: monitor fallito, servizio recuperato sullo stesso nodo, `fail-count=1` |
| 28/11/2026 | `pcs resource cleanup ch23-nginx` | PASS: risorse attive, nessun failed action residua |
| 28/11/2026 | `stonith_admin --history='*'` | `0 events found`; **non contraddice il fencing** |
| 28/11/2026 | `journalctl -u pacemaker` sulla finestra del 27/11 | PASS: perdita membro → fence richiesto → spegnimento riuscito → avvio della Dummy |
| 28/11/2026 | Due checkpoint Hyper-V `CH24-QUORUM-FENCING-VALIDATED` | PASS: A alle 15:18:30 e B alle 15:18:33 |

**Non dimostrato:** split-brain con accesso simultaneo a dati reali, sicurezza contro ogni partizione, recovery dopo guasto dell'host Hyper-V, boot automatico del cluster, downtime del servizio durante failover. Il fencing R2 è didattico; uno snapshot di VM non costituisce consistenza distribuita.

Screenshot originali raccolti nella chat di laboratorio: quorum, configurazioni Corosync/STonith, vincoli, gruppo web, monitor fail Nginx, cleanup, estratti journal e checkpoint. **Il repository contiene Markdown e procedure, non immagini di log con indirizzi o altri dati d'ambiente non necessari.**

Fonti correlate: [R2 automatico](../../laboratorio-fencing-esterno-hyperv/procedure/02-fencing-reciproco-r2.md), [Appendice C Nginx](../../laboratorio-fencing-esterno-hyperv/appendice-c-nginx-ha/procedura.md).
