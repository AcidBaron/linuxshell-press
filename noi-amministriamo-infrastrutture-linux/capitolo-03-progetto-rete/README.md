# Capitolo 3 – Progettare la rete del laboratorio

Materiale operativo associato al Capitolo 3 di **Noi Amministriamo Infrastrutture Linux**.

Questo capitolo consolida la rete già funzionante e definisce il contratto tecnico usato dai servizi successivi.

## Piano IPv4

| Ruolo | Indirizzo / intervallo |
|---|---|
| Gateway LAB-LAN / fw01 | `10.77.0.1` |
| Infrastruttura statica | `10.77.0.2–99` |
| Provisioning temporaneo golden | `10.77.0.100` |
| linux-client01 | `10.77.0.101` |
| Pool DHCP | `10.77.0.102–199` |
| Infrastruttura alta | `10.77.0.200–239` |
| Host Hyper-V | `10.77.0.254` |

DNS interno previsto: `10.77.0.10`; dominio: `lab.test`.

## Materiale correlato

- `linux/network-preflight.sh` — fotografia di routing, neighbor table e failure test pre-DNS.
- Il provisioning automatico delle VM è mantenuto nel laboratorio parallelo [`laboratorio-provisioning-golden-image`](../laboratorio-provisioning-golden-image/), con script canonico `New-LabLinuxVM-R2_2.ps1`.
