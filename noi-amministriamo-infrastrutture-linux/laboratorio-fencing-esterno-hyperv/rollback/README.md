# Arresto e rollback del prototipo

Il progetto R1 è sperimentale e non modifica automaticamente i servizi Pacemaker del Capitolo 23.

Per disabilitare il dispositivo STONITH di prova, da un nodo del cluster:

```bash
sudo pcs stonith disable ch23-fence-hyperv-lab --wait=30
sudo pcs stonith status
```

Per rimuovere completamente la *risorsa PCS* (solo se non serve più):

```bash
sudo pcs stonith delete ch23-fence-hyperv-lab
```

L'eliminazione della risorsa non elimina gli script installati in `/usr/sbin/fence_hyperv_lab` né le chiavi SSH.

Non eliminare i file `administrators_authorized_keys` di Windows: può contenere chiavi di altri utenti. Per revocare l'esperimento, rimuovere **esclusivamente** le due righe contrassegnate `ch23-fencing-linux-client01` e `ch23-fencing-dhcp-client01` dopo aver verificato che non servano più.

R1 può spegnere `web01` anche quando è un backend applicativo: non lasciare l'agente esposto a test automatici non supervisionati. Non eseguire `stonith_admin --fence` sui nodi del cluster con questa configurazione.
