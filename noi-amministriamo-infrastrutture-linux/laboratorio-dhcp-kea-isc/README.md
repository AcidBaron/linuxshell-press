# Laboratorio parallelo – DHCP con Kea: lease, reservation e compatibilità ISC DHCP legacy

Materiale operativo del laboratorio inserito fra Capitolo 4 e Capitolo 5.

## Stato finale

- Server: `dhcp01` — `10.77.0.30/24`.
- Server DHCPv4 finale: Kea 2.4.1.
- Pool: `10.77.0.102–199`.
- Reservation: MAC `00:15:5d:01:07:0e` → `10.77.0.150`.
- Gateway distribuito: `10.77.0.1`.
- DNS distribuito: `10.77.0.10`.
- Dominio: `lab.test`.
- IPv6: RA/SLAAC; DHCPv6 non usato.
- `isc-dhcp-server`: testato come ramo legacy, stato finale `disabled/inactive`.

## File

- `kea/kea-dhcp4.conf` — configurazione moderna finale.
- `client/10-lab-dhcp.yaml` — Netplan finale del client.
- `legacy/dhcpd.conf.ISC-RESERVATION-VALIDATED` — ISC DHCP con `fixed-address .150`.
- `legacy/dhcpd.conf.ISC-DYNAMIC-VALIDATED` — ISC DHCP con solo pool dinamico.
- `legacy/isc-dhcp-server.default` — interfaccia IPv4 usata nel test legacy.
- `bind/dhcp01.records` — record A/PTR aggiunti a BIND.
- `rollback/restore-kea.sh` — ritorno allo stato moderno stabile.

## Failure case preservati

Il laboratorio documenta anche il client DHCP senza server, una cattura `tcpdump` avviata fuori finestra e il primo avvio ISC fallito perché non era ancora configurata alcuna interfaccia. Sono diagnostica reale, non configurazione finale.
