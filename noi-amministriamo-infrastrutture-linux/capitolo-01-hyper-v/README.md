# Capitolo 1 – Laboratorio di riferimento con Windows 11 e Hyper-V

Materiale operativo associato al Capitolo 1 di **Noi Amministriamo Infrastrutture Linux**.

## Baseline validata

- Host: Windows 11 Pro con Hyper-V.
- Switch interno: `LAB-LAN`.
- Host su LAB-LAN: `10.77.0.254/24`.
- Router VM: `fw01`.
- WAN `fw01`: Hyper-V Default Switch, DHCP.
- LAN `fw01`: `10.77.0.1/24`.
- Checkpoint finale: `BASE-OS-INSTALLED`.

## File

- `powershell/host-hyperv-lab.ps1` — inventario host/storage, creazione LAB-LAN e creazione della VM `fw01`.
- `linux/verify-fw01-baseline.sh` — verifiche lato guest dopo l'installazione.
- `powershell/fw01-postinstall.ps1` — verifica SSH dall'host, rimozione ISO, inventario NIC/MAC e checkpoint.

## Nota d'uso

I file raccolgono i blocchi realmente descritti nel capitolo. Prima di eseguirli verificare percorsi locali, nome dell'ISO e stato delle VM. Il libro contiene spiegazioni, condizioni di PASS e contesto completo.
