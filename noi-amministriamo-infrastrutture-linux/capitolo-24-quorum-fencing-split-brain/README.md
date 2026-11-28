# Capitolo 24 — Quorum, fencing e split-brain

Laboratorio eseguito il **28 novembre 2026** sul cluster `ch23-cluster` dei capitoli e delle appendici precedenti. L'obiettivo è interpretare quorum, regole di fencing, monitoraggio delle risorse e log di recupero, senza reinstallare componenti o ripetere spegnimenti distruttivi.

- [Procedura operativa verificata](procedure/01-quorum-fencing-split-brain.md)
- [Evidenze e limiti dei test](procedure/02-evidenze-e-limiti.md)

**Stato:** quorum, configurazione e recovery di Nginx verificati il 28/11; la sequenza del fencing automatico del **27/11** è stata recuperata dal journal il 28/11. È stato creato il checkpoint `CH24-QUORUM-FENCING-VALIDATED` su **entrambi** i nodi. Non è stata provocata una nuova partizione né simulato uno split-brain con scritture concorrenti.

Riferimenti tecnici già pubblicati:
- [Capitolo 23 — installazione e cluster](../capitolo-23-pacemaker-corosync/)
- [Fencing esterno Hyper-V R2](../laboratorio-fencing-esterno-hyperv/procedure/02-fencing-reciproco-r2.md)
- [Appendice C — gruppo web Nginx + VIP](../laboratorio-fencing-esterno-hyperv/appendice-c-nginx-ha/procedura.md)

Gli agenti R1/R2 sono prototipi didattici, **non certificati per la produzione**; l'host Hyper-V rappresenta un singolo punto di guasto.
