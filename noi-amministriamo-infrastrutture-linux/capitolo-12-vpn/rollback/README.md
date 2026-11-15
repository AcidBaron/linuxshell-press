# Capitolo 12 – rollback

La via preferita nel laboratorio è il checkpoint Hyper-V.

- checkpoint iniziale: `CH12-PRE-STABLE-VPN-WAN`
- checkpoint finale: `CH12-VPN-FINAL-VALIDATED`

Lavorare dalla connessione amministrativa LAB-LAN.

## 1. Riportare la WAN sullo switch precedente

```powershell
Connect-VMNetworkAdapter `
    -VMName "fw01" `
    -Name "WAN" `
    -SwitchName "Default Switch"
```

## 2. Ripristinare Netplan

Usare il backup `/etc/netplan.pre-ch12-vpn-wan`, quindi validare e applicare la configurazione ripristinata.

```bash
sudo netplan generate
sudo netplan apply

ip -4 -br addr show eth0
ip route show default
```

## 3. Rimuovere WinNAT e VPN-WAN

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

Dopo il rollback verificare route di default, Internet, DNS e listener VPN.
