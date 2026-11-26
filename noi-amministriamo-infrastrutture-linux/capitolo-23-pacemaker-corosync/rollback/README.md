# Ripristino del Capitolo 23

Il punto precedente al laboratorio è `CH23-PRE-PACEMAKER-COROSYNC` su **entrambe** le VM; il punto validato è `CH23-PACEMAKER-COROSYNC-COMPLETE` su entrambe.

**Non applicare il checkpoint di una sola VM mentre l'altra sta eseguendo il cluster.** Fermare e coordinare entrambi i nodi; il ripristino di snapshot non sostituisce un backup coerente di applicazioni o dati.

Per annullare un vincolo amministrativo temporaneo ancora presente, verificare prima `sudo pcs constraint config --full`, poi utilizzare `sudo pcs resource clear <nome-risorsa>` solo se quel vincolo appartiene alla risorsa prevista.

La risorsa sperimentale `ch23-fence-hyperv-lab`, aggiunta successivamente nel laboratorio parallelo, è fuori dallo stato del checkpoint originale; non va confusa con i due servizi del Capitolo 23.

La deroga `stonith-enabled=false` è documentata ed è inadatta alla produzione.
