# Stato finale pfSense

## Oggetti pfSense

| Oggetto | Configurazione finale |
|---|---|
| LAN | `10.88.0.1/24`, untagged/native |
| VLAN10 | `hn1` tag 10, `10.88.10.1/24` |
| VLAN20 | `hn1` tag 20, `10.88.20.1/24` |
| Alias RFC1918_NETS | `10.0.0.0/8`; `172.16.0.0/12`; `192.168.0.0/16` |
| DNS Resolver | Enabled; Forwarding Mode ON; DNSSEC OFF nel laboratorio |
| Outbound NAT | Automatic |
| Rules VLAN10 | ICMP gateway; DNS gateway; BLOCK RFC1918; PASS Internet |
| Rules VLAN20 | ICMP gateway; DNS gateway; BLOCK RFC1918; PASS Internet |

## Indirizzamento

```text
PFSENSE-LAN / management: 10.88.0.0/24
VLAN10:                   10.88.10.0/24
VLAN20:                   10.88.20.0/24

pfsense01 LAN             10.88.0.1
pfsense01 VLAN10          10.88.10.1
pfsense01 VLAN20          10.88.20.1
pfs-client01              10.88.0.101
pfs-vlan10-client01       10.88.10.101
pfs-vlan20-client01       10.88.20.101
```
