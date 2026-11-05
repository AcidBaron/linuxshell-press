# Capitolo 8 – Samba

Materiale operativo associato al Capitolo 8 di **Noi Amministriamo Infrastrutture Linux**.

## Stato finale validato

- Server: `files01`, IPv4 `10.77.0.20`.
- Samba 4.19.5 su Ubuntu 24.04.
- Modalità: standalone server.
- Share: `[dati]` -> `/srv/samba/dati`.
- SMB diretto su TCP/445; NetBIOS legacy non è la baseline.
- `interfaces = lo eth0` e `bind interfaces only = yes`.
- Firma SMB richiesta.
- UFW limita TCP/22 e TCP/445 alle reti del laboratorio.
- Checkpoint prima del reboot finale: `CH8-SAMBA-PRE-REBOOT`.

## File

- `config/smb.conf` — configurazione Samba finale.
- `bind/files01.records` — record A/PTR aggiunti al DNS.
- `linux/configure-ufw.sh` — policy firewall applicata a `files01`.
- `linux/verify-samba.sh` — controlli di configurazione, listener e accesso SMB.
- `powershell/checkpoint.ps1` — checkpoint finale prima del reboot.
- `windows/verify-files01.ps1` — test TCP/445 e TCP/22 dal client Windows.
- `rollback/README.md` — rollback Samba, BIND, UFW e Hyper-V.

## Diagnostica non finale

Il test systemd `ipv6-ready` usato per diagnosticare la race dell'indirizzo SLAAC al boot è stato rimosso dopo la prova. Non fa parte della configurazione operativa. Il capitolo finale non include TrueNAS.
