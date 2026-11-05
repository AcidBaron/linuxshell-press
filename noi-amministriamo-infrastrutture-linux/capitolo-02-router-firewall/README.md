# Capitolo 2 – Costruire un router/firewall Linux

Materiale operativo associato al Capitolo 2 di **Noi Amministriamo Infrastrutture Linux**.

## Stato validato

- `fw01` inoltra traffico IPv4 fra LAB-LAN e WAN.
- nftables è la configurazione ufficiale e persistente.
- `linux-client01` possiede una sola NIC su LAB-LAN.
- Il client raggiunge gateway, Internet, DNS e HTTPS passando realmente da `fw01`.
- Checkpoint finali: `ROUTER-FIREWALL-VALIDATED` e `LAB-LAN-CLIENT-VALIDATED`.

## File

- `config/99-fw01-router.conf` — abilita `net.ipv4.ip_forward=1` in modo persistente.
- `config/nftables.conf` — ruleset finale validato del router/firewall.
- `linux/preflight-and-verify.sh` — controlli preflight e verifiche post-configurazione.
- `powershell/create-linux-client01.ps1` — creazione Hyper-V del client isolato.
- `powershell/checkpoints.ps1` — checkpoint finali del capitolo.
- `legacy/fw01-iptables.sh` — equivalente iptables proposto come esercizio/migrazione; non è la baseline ufficiale.
- `rollback/README.md` — rollback locale e tramite checkpoint.

## Autorità della configurazione

La baseline ufficiale del capitolo usa nftables nativo. Il materiale `legacy/` serve a leggere o migrare ambienti esistenti e non sostituisce il ruleset finale.
