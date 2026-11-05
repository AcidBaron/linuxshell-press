# Noi Amministriamo Infrastrutture Linux — materiali operativi

Questa directory raccoglie gli script, i comandi e le configurazioni realmente usati e validati nei laboratori del libro **Noi Amministriamo Infrastrutture Linux** (Linuxshell Press).

Il repository non sostituisce il testo del libro: il volume descrive prerequisiti, motivazioni, rischi, verifiche, failure case e rollback. Qui sono raccolti gli artefatti da copiare o confrontare durante il laboratorio.

## Capitoli

- [Capitolo 1 – Hyper-V e laboratorio di riferimento](./capitolo-01-hyper-v/)
- [Capitolo 2 – Router/firewall Linux](./capitolo-02-router-firewall/)
- [Capitolo 3 – Progettare la rete](./capitolo-03-progettare-rete/)
- [Capitolo 4 – DNS con BIND9](./capitolo-04-bind9-dns/)
- [Capitolo 5 – VLAN e segmentazione](./capitolo-05-vlan/)
- [Capitolo 6 – IPv6](./capitolo-06-ipv6/)
- [Capitolo 7 – Reti miste Linux e Windows](./capitolo-07-reti-miste-linux-windows/)
- [Capitolo 8 – Samba](./capitolo-08-samba/)

## Laboratori paralleli

- [Provisioning automatico di VM Linux da golden image](./laboratorio-provisioning-golden-image/)
- [pfSense – installazione e configurazione iniziale](./laboratorio-pfsense-installazione/)
- [pfSense – routing, NAT, DNS, VLAN e segmentazione](./laboratorio-pfsense-routing-nat-dns-vlan/)
- [DHCP con Kea e compatibilità ISC DHCP legacy](./laboratorio-dhcp-kea-isc/)

## Convenzioni

- `comandi.md`: sequenza operativa estratta dal master revisionato.
- `configurazioni/`: file finali validati.
- `diagnostica/`: esperimenti o workaround temporanei, non stato finale.
- `legacy/`: implementazioni storiche provate per compatibilità.
- `SHA256SUMS`: checksum degli artefatti operativi standalone.

Le configurazioni sono quelle del laboratorio del libro (`10.77.0.0/24`, `lab.test`, nomi VM e interfacce osservati). Non vanno applicate alla cieca in ambienti diversi.
