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

## Rollback manuale

Lavorare dalla connessione amministrativa LAB-LAN.

### fw01

```bash
sudo systemctl disable --now wg-quick@wg0
sudo systemctl disable --now openvpn-server@ch12

if [ -f /etc/nftables.conf.pre-ch12-final ]; then
    sudo cp -a /etc/nftables.conf.pre-ch12-final /etc/nftables.conf
    sudo nft -c -f /etc/nftables.conf
    sudo nft -f /etc/nftables.conf
fi

sudo rm -f /etc/netplan/90-ch12-vpn-wan.yaml
sudo cp -a /etc/netplan.pre-ch12-vpn-wan/. /etc/netplan/
sudo netplan generate
sudo netplan apply

ip -4 -br addr show eth0
ip route show default
```

### infra01

```bash
sudo cp -a \
    /etc/bind/named.conf.options.pre-ch12-wireguard \
    /etc/bind/named.conf.options

sudo named-checkconf
sudo rndc reload
```

### Host Windows / Hyper-V

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

Il rollback è riuscito solo se `fw01` recupera il percorso WAN precedente, nftables torna alla baseline, BIND non autorizza più le subnet VPN e la gestione via LAB-LAN resta disponibile.
