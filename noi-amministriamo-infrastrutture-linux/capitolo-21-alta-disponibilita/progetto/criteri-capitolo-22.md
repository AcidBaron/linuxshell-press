# Progetto — Criteri per il Capitolo 22: Keepalived e VRRP

Questo documento è un **piano di lavoro**, non il resoconto di un laboratorio già eseguito.

## Vincoli architetturali

1. Non creare una nuova VM senza necessità tecnica dimostrata.
2. Riutilizzare rp01 come riferimento del servizio Nginx esistente.
3. Selezionare il secondo nodo fra le VM già presenti, dopo aver verificato conflitti di servizi, memoria/CPU/disco e connettività.
4. Proteggere gli stati precedenti con un checkpoint mirato e una procedura di rollback, **prima** di modificare la VM scelta.
5. Scegliere una VIP compatibile con LAB-LAN soltanto dopo verifica degli indirizzi usati e della rete Hyper-V.
6. Mantenere invariato nextcloud.lab.test finché VIP e failover non sono stati validati.
7. Dichiarare che web01/MariaDB e l'host fisico restano SPOF.

## Criteri di collaudo futuri

| Prova | Esito necessario |
|---|---|
| Stato nominale | VIP assegnata a un solo nodo e servizio raggiungibile via URL |
| Nginx fermo sul primario | Il secondario subentra e l'URL HTTPS torna operativo |
| Nodo primario indisponibile | VIP sul secondario e risposta applicativa verificata |
| Primario di nuovo operativo | Failback conforme alla politica adottata, senza flapping |
| web01 indisponibile | Nessun falso PASS dell'applicazione soltanto perché il proxy risponde |
| Coesistenza | Nessuna regressione sui servizi preesistenti nella VM scelta |

Il tempo di interruzione va misurato da un client con timestamp e sonde applicative, **non dedotto** dal solo stato VRRP. La continuità delle sessioni in corso non è garantita dal trasferimento della VIP.

## Confine con il Capitolo 23

Keepalived/VRRP: failover dell'indirizzo virtuale e controllo del servizio di ingresso.

Pacemaker/Corosync: orchestrazione delle risorse cluster, quorum, split-brain e fencing. Non presentare questi ultimi meccanismi come già configurati nel Capitolo 22.
