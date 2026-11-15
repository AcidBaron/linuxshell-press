# Capitolo 12 - rollback

La via di rollback preferita nel laboratorio è il checkpoint Hyper-V.

- checkpoint iniziale: `CH12-PRE-STABLE-VPN-WAN`
- checkpoint finale: `CH12-VPN-FINAL-VALIDATED`

## Ripristino manuale

Lavorare mantenendo disponibile la connessione amministrativa LAB-LAN.

Riportare la WAN di `fw01` sullo switch precedente:

```powershell
Connect-VMNetworkAdapter `
    -VMName "fw01" `
    -Name "WAN" `
    -SwitchName "Default Switch"
```

Ripristinare la configurazione Netplan dal backup creato prima della modifica, quindi verificare route, Internet e DNS.

Rimuovere WinNAT e lo switch interno:

```powershell
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

Dopo il rollback verificare route di default, accesso Internet, DNS e listener VPN.
