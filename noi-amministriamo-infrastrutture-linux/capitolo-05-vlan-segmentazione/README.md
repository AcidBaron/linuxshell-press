# Capitolo 5 – VLAN, segmentazione e reti multiple

Materiale operativo associato al Capitolo 5 di **Noi Amministriamo Infrastrutture Linux**.

## Stato validato

- `fw01` mantiene la management LAN su `eth1` e usa `eth2` come trunk 802.1Q.
- VLAN 10: `10.77.10.0/24`, gateway `10.77.10.1`.
- VLAN 20: `10.77.20.0/24`, gateway `10.77.20.1`.
- Le VLAN raggiungono Internet e il DNS centrale.
- Traffico inter-VLAN e accesso generico alla management LAN restano bloccati.

## File

- `fw01/50-cloud-init.yaml` — Netplan finale con subinterfacce VLAN.
- `fw01/nftables.conf` — policy finale di segmentazione e NAT IPv4.
- `infra01/named.conf.options` — ACL BIND estesa alle VLAN.
- `infra01/named.conf.local` — zone reverse aggiuntive.
- `infra01/db.lab.test` — record A dei client VLAN.
- `infra01/db.10.77.10` e `db.10.77.20` — reverse zone.
- `clients/vlan10-10-lab-static.yaml` e `vlan20-10-lab-static.yaml`.
- `powershell/hyper-v-vlan.ps1` — trunk e porte Access usati nel laboratorio.
- `legacy/README.md` — esempi ifupdown/vconfig mantenuti solo per manutenzione legacy.
