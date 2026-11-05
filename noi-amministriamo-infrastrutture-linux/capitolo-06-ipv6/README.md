# Capitolo 6 – IPv6 nell'infrastruttura moderna

Materiale operativo associato al Capitolo 6 di **Noi Amministriamo Infrastrutture Linux**.

## Architettura finale

- Management: `fd3a:7b4c:2d91:1::/64`.
- VLAN 10: `fd3a:7b4c:2d91:10::/64`.
- VLAN 20: `fd3a:7b4c:2d91:20::/64`.
- Prefisso interno aggregato: `fd3a:7b4c:2d91::/48`.
- `fw01` inoltra IPv6 e invia RA/SLAAC, ma non annuncia una default route IPv6.
- Nessun NAT66.
- `infra01` usa IPv6 statico e BIND9 dual-stack.
- I client VLAN restano SLAAC: nessun indirizzo ULA statico nei loro Netplan.

## File

- `fw01/50-cloud-init.yaml`
- `fw01/60-ipv6-router.conf`
- `fw01/radvd.conf`
- `fw01/nftables.conf`
- `infra01/10-lab-static.yaml`
- `infra01/named.conf.options`
- `infra01/named.conf.local`
- `infra01/db.lab.test`
- `infra01/db.fd3a-7b4c-2d91-1`
- `linux/verify-ipv6.sh`

Il capitolo conserva esplicitamente i failure case NDP bloccato, RA accettati dal router e differenza fra route IPv6 e policy firewall.
