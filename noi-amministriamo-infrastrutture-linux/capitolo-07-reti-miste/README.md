# Capitolo 7 – Reti miste Linux e Windows

Materiale operativo associato al Capitolo 7 di **Noi Amministriamo Infrastrutture Linux**.

## Stato persistente finale su Windows

- OpenSSH Client: installato.
- OpenSSH Server: installato.
- `sshd`: Running / Automatic.
- Regola Microsoft `OpenSSH-Server-In-TCP`: disabilitata.
- Regola `CH7-OpenSSH-LAB-LAN`: abilitata su TCP/22, limitata a `vEthernet (LAB-LAN)`.
- Sorgenti consentite: `10.77.0.0/24` e `fd3a:7b4c:2d91:1::/64`.
- NRPT `.lab.test`: resolver `10.77.0.10`.
- Connection-specific suffix della LAB-LAN: vuoto, dopo il test temporaneo.

## File

- `windows/configure-lab-dns-openssh.ps1` — NRPT, OpenSSH Server e firewall ristretto alla LAB-LAN.
- `windows/verify-windows.ps1` — verifica rete, DNS, listener e firewall.
- `windows/file-transfer-examples.ps1` — esempi SCP/SFTP e hash.
- `linux/verify-windows-ssh.sh` — test dal client Linux verso Windows.
- `rollback/rollback-windows.ps1` — rimozione selettiva delle sole modifiche del capitolo.

Nessun file Linux persistente è stato modificato nel Capitolo 7.
