# Pacemaker/Corosync — percorso validato

Eseguire da `linux-client01` salvo indicazione contraria; i comandi sono **estratti dai passaggi realmente collaudati**, non uno script da lanciare in blocco su sistemi già configurati. Conservare gli snapshot pre-laboratorio. Per una ricostruzione completa seguire il Capitolo 23 del libro.

## Costruzione e avvio del cluster

Dopo installazione dei pacchetti, configurazione dell'account `hacluster`, autenticazione PCS e distruzione *controllata* dei vecchi cluster singleton `debian` su entrambi i nodi:

```bash
sudo pcs cluster setup ch23-cluster linux-client01 addr=10.77.0.101 dhcp-client01 addr=10.77.0.150
sudo pcs cluster start --all
sudo pcs status
```

Per il laboratorio senza fence agent compatibile con Hyper-V si è esplicitamente impostato:

```bash
sudo pcs property set stonith-enabled=false
```

**Non trasferire questa impostazione in produzione.**

## Risorsa Dummy

```bash
sudo pcs resource create ch23-demo ocf:pacemaker:Dummy op monitor interval=10s
sudo pcs resource config ch23-demo
sudo pcs resource move ch23-demo linux-client01 --wait=30
sudo pcs resource disable ch23-demo --wait=30
sudo pcs resource enable ch23-demo --wait=30
sudo crm_resource --resource ch23-demo --fail --node dhcp-client01
sudo pcs resource cleanup ch23-demo
sudo pcs resource failcount show ch23-demo
```

Questi comandi documentano prove successive, **non** una sequenza idempotente da ripetere automaticamente.

## VIP distinta da Keepalived

Prima della creazione sono state verificate la disponibilità di `10.77.0.91` tramite `arping -D` e l'assenza di PTR con `dig`; controllo valido per il momento della prova.

```bash
sudo pcs resource create ch23-vip ocf:heartbeat:IPaddr2 ip=10.77.0.91 cidr_netmask=24 nic=eth0 op monitor interval=10s
sudo pcs resource move-with-constraint ch23-vip dhcp-client01 --wait=30
sudo pcs constraint config --full
sudo pcs resource clear ch23-vip
sudo pcs status
```

La collocazione è stata verificata anche con `ip -4 -br addr show dev eth0` su **entrambi** i nodi. `pcs resource move` senza vincolo persistente aveva restituito un errore non distruttivo, mentre `move-with-constraint` è riuscito.

## Stato finale al checkpoint del capitolo

- Due nodi online e quorum.
- `ch23-demo`: Started `dhcp-client01`.
- `ch23-vip`: Started `linux-client01`.
- Nessun location constraint residuo.
- `stonith-enabled=false`.
- Checkpoint `CH23-PACEMAKER-COROSYNC-COMPLETE` su entrambe le VM.

Non sono stati simulati split-brain o guasti reali di nodi in questo capitolo. Il laboratorio di fencing Hyper-V, sviluppato **dopo** il checkpoint, è documentato separatamente.
