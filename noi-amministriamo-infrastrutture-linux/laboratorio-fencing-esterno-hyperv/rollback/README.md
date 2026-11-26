# Arresto e rollback dei prototipi R1 e R2

R1 e R2 sono sperimentali. R2 agisce sui nodi stessi del cluster e può arrestarli bruscamente: prima del rollback verificare che entrambi siano online e che i servizi necessari siano disponibili. Non accendere automaticamente VM sconosciute o in stato ambiguo.

Per disabilitare i dispositivi STONITH da un nodo del cluster, se si decide di terminare il laboratorio:

```bash
sudo pcs stonith disable ch23-fence-linux --wait=30
sudo pcs stonith disable ch23-fence-dhcp --wait=30
sudo pcs stonith disable ch23-fence-hyperv-lab --wait=30
sudo pcs stonith status
```

Per rimuovere completamente le *risorse PCS* (solo se non servono più; verificare e rimuovere anche i rispettivi vincoli di posizione):

```bash
sudo pcs constraint config --full
# Rimuovere i vincoli di R2 per ID con 'pcs constraint remove <ID>' prima di eliminare le risorse.
sudo pcs stonith delete ch23-fence-linux
sudo pcs stonith delete ch23-fence-dhcp
sudo pcs stonith delete ch23-fence-hyperv-lab
```

L'eliminazione delle risorse non elimina gli script installati in `/usr/sbin/fence_hyperv_lab` e `/usr/sbin/fence_hyperv_lab_r2`, né le chiavi SSH. Questa procedura descrive un eventuale rollback futuro: **non è stata eseguita dopo il PASS R2**.

Non eliminare i file `administrators_authorized_keys` di Windows: può contenere chiavi di altri utenti. Per revocare l'esperimento, rimuovere **esclusivamente** le due righe contrassegnate `ch23-fencing-linux-client01` e `ch23-fencing-dhcp-client01` dopo aver verificato che non servano più.

R1 può spegnere `web01` anche quando è un backend applicativo: non lasciare l'agente esposto a test automatici non supervisionati. Non eseguire `stonith_admin --fence` sui nodi del cluster con questa configurazione.
