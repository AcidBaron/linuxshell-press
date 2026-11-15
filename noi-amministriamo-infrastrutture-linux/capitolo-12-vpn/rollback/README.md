# Capitolo 12 – rollback e checkpoint

La via di rollback preferita nel laboratorio è il checkpoint Hyper-V.

Checkpoint iniziale:

`CH12-PRE-STABLE-VPN-WAN`

Checkpoint finale:

`CH12-VPN-FINAL-VALIDATED`

## Checkpoint finale

```powershell
Checkpoint-VM `
    -Name "fw01" `
    -SnapshotName "CH12-VPN-FINAL-VALIDATED"
```

## Rollback manuale della VPN-WAN

Lavorare dalla connessione amministrativa LAB-LAN e procedere nell'ordine inverso.

```powershell
Connect-VMNetworkAdapter `
    -VMName "fw01" `
    -Name "WAN" `
    -SwitchName "Default Switch"

Remove-NetNat `
    -Name "VPN-WAN-NAT"

Remove-NetIPAddress `
    -InterfaceAlias "vEthernet (VPN-WAN)" `
    -IPAddress 10.250.0.1 `
    -Confirm:$false

Remove-VMSwitch `
    -Name "VPN-WAN" `
    -Force
```

La configurazione Linux deve essere ripristinata usando il backup di Netplan creato prima della modifica, mantenendo un percorso amministrativo alternativo. Dopo il rollback verificare route di default, Internet, DNS e listener VPN.
