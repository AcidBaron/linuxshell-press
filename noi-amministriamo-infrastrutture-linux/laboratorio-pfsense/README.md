# Laboratorio parallelo – pfSense

Questo percorso raccoglie i due laboratori pfSense del libro: installazione iniziale e confronto operativo con routing/NAT/DNS/VLAN/segmentazione.

## Struttura

- `setup-iniziale/` — creazione di PFSENSE-LAN, VM `pfsense01`, boot order e checkpoint.
- `routing-vlan/` — trunk Hyper-V, route host Windows e stato finale delle VLAN.

## Stato finale complessivo

- Management: `10.88.0.0/24`, pfSense `10.88.0.1`, host `10.88.0.254`.
- VLAN10: `10.88.10.0/24`, gateway `10.88.10.1`.
- VLAN20: `10.88.20.0/24`, gateway `10.88.20.1`.
- pfSense CE 2.9.0-RELEASE.
- Outbound NAT: Automatic.
- DNS Resolver: Enabled, Forwarding Mode ON, DNSSEC OFF nel laboratorio.
- Alias `RFC1918_NETS`: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`.
- Regole VLAN: ICMP gateway, DNS gateway, BLOCK RFC1918, PASS Internet.

pfSense è configurato tramite WebGUI; non sono stati modificati manualmente file interni dell'appliance.
