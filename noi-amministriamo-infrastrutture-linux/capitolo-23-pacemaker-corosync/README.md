# Capitolo 23 — Pacemaker e Corosync

Materiale operativo validato il **26 novembre 2026** per *Noi Amministriamo Infrastrutture Linux* (Linuxshell Press).

## Ambito e nodi

Il laboratorio riutilizza due VM Ubuntu 24.04.5 già esistenti sulla rete Hyper-V `LAB-LAN`:

| Nodo | IPv4 | Rete | Note |
|---|---|---|---|
| linux-client01 | 10.77.0.101/24 | eth0 | indirizzo statico |
| dhcp-client01 | 10.77.0.150/24 | eth0 | prenotazione Kea |
| VIP Pacemaker | 10.77.0.91/24 | eth0 | distinta dalla VIP Keepalived 10.77.0.90 del cap. 22 |

Cluster: `ch23-cluster`, Corosync + Pacemaker 2.1.6, PCS 0.11.7. Due nodi online, quorum presente. Sono stati riutilizzati i sistemi esistenti, senza nuove VM.

## Configurazione finale verificata

- `ch23-demo` — `ocf:pacemaker:Dummy`, monitor ogni 10 s, Started su `dhcp-client01`.
- `ch23-vip` — `ocf:heartbeat:IPaddr2`, `ip=10.77.0.91 cidr_netmask=24 nic=eth0`, monitor ogni 10 s, Started su `linux-client01`.
- Nessun vincolo di collocazione residuo.
- `stonith-enabled=false` **solo per questo laboratorio didattico**: non è una configurazione HA sicura per produzione.
- `corosync` e `pacemaker` risultavano `active/disabled`; `pcsd` `active/enabled`.

Il capitolo è stato chiuso prima del laboratorio parallelo di fencing. Successivamente è stata registrata la risorsa sperimentale `ch23-fence-hyperv-lab` (tipo `fence_hyperv_lab`), senza cambiare `stonith-enabled=false`; tale evoluzione **non fa parte del checkpoint finale del Capitolo 23**.

## Prove realmente effettuate

1. Preparazione: pacemaker, corosync, pcs, resource-agents-base, fence-agents-base; autenticazione `hacluster` e porte UFW peer TCP/2224, UDP/5405.
2. Rimozione dei cluster locali predefiniti `debian` presenti sui due sistemi; creazione `ch23-cluster`, avvio, nodi online e quorum.
3. Dummy: create, move, disable/enable, errore simulato tramite `crm_resource --fail`, cleanup e assenza finale di failcount.
4. VIP `10.77.0.91`: ARP duplicate-address probe senza risposta e verifica PTR; risorsa IPaddr2 creata, spostata e verificata su `eth0` di entrambi i nodi.
5. `pcs resource move` inizialmente rifiutato per impossibilità di garantire la collocazione dopo la rimozione del vincolo; `move-with-constraint` riuscito; `pcs resource clear` ha rimosso `cli-prefer-ch23-vip` e la VIP è tornata su `linux-client01`.
6. Check finale PCS: entrambi i nodi online, quorum, due risorse Started e nessun vincolo residuo.

## Checkpoint Hyper-V

- `CH23-PRE-PACEMAKER-COROSYNC`: presente su entrambe le VM, recupero precedente al laboratorio.
- `CH23-PACEMAKER-COROSYNC-COMPLETE`: creato **26/11/2026 17:58:10** su `linux-client01` e **17:58:12** su `dhcp-client01`.

I checkpoint dei nodi di un cluster non vanno ripristinati separatamente mentre il peer è operativo: gestire il ripristino in modo coordinato e a cluster arrestato.

## Materiali

- [Procedura riassuntiva e verifiche](procedure/01-laboratorio-validato.md)
- [Rollback e limiti](rollback/README.md)
- [Laboratorio parallelo — Realizzare un dispositivo di fencing esterno](../laboratorio-fencing-esterno-hyperv/)

**Nota editoriale:** il manoscritto DOCX con immagini e troubleshooting resta in revisione; questo repository raccoglie procedure e materiale operativo, non una copia non approvata del libro. Non sono pubblicati `authkey`, credenziali, chiavi SSH private o esportazioni di configurazione non verificate.
