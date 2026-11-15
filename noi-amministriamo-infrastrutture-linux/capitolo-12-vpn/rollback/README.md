# Capitolo 12 – rollback della VPN-WAN

La via preferita nel laboratorio è il checkpoint Hyper-V.

- pre-change: `CH12-PRE-STABLE-VPN-WAN`
- finale: `CH12-VPN-FINAL-VALIDATED`

## 1. Riportare la WAN di fw01 sullo switch precedente

Da PowerShell amministrativa:

```powershell
Connect-VMNetworkAdapter `
    -VMName "fw01" `
    -Name "WAN" `
    -SwitchName "Default Switch"
```

## 2. Ripristinare Netplan

Prima della modifica era stata creata la copia `/etc/netplan.pre-ch12-vpn-wan`. Ripristinare la configurazione coerente con lo stato precedente, poi:

```bash
sudo netplan generate
sudo netplan apply
ip -4 -br addr show eth0
ip route show default
```

## 3. Rimuovere WinNAT e VPN-WAN

```powershell
Remove-NetNat -Name "VPN-WAN-NAT"

Remove-NetIPAddress `
    -InterfaceAlias "vEthernet (VPN-WAN)" `
    -IPAddress 10.250.0.1 `
    -Confirm:$false

Remove-VMSwitch -Name "VPN-WAN" -Force
```

## 4. Verifica

Controllare route di default, Internet, DNS, listener VPN e raggiungibilità amministrativa dalla LAB-LAN.