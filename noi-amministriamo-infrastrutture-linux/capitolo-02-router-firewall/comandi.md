# Capitolo 2 – Costruire un router/firewall Linux — comandi e configurazioni
> Estratto operativo dal master `Capitoli_01_02_Laboratorio_HyperV_Router_Firewall_REVISIONATI.docx`. I blocchi sono riportati nell'ordine del capitolo.

## 2.1 Topologia e obiettivo del traffico

```bash
linux-client01 10.77.0.101
        |
      LAB-LAN
        |
   eth1 10.77.0.1
      [fw01]
   eth0 DHCP 172.30.x.x
        |
Default Switch / NAT Windows
        |
     Internet
```

## 2.2 Preflight: forwarding, nftables e UFW

```bash
ip -br addr
ip route
sysctl net.ipv4.ip_forward
command -v nft
sudo nft list ruleset
systemctl status nftables --no-pager
dpkg -l nftables | grep '^ii'
dpkg -l ufw | grep '^ii'
sudo ufw status verbose
```

## 2.3 Abilitare il forwarding IPv4 in modo persistente

```bash
sudo tee /etc/sysctl.d/99-fw01-router.conf > /dev/null <<'EOF'
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system
sysctl net.ipv4.ip_forward
cat /proc/sys/net/ipv4/ip_forward
```

## 2.4 Salvare la configurazione nftables originale

```bash
sudo cp -a /etc/nftables.conf /etc/nftables.conf.original
sudo cat /etc/nftables.conf
```

## 2.5 Il ruleset finale nftables

```bash
sudo tee /etc/nftables.conf > /dev/null <<'EOF'
#!/usr/sbin/nft -f

flush ruleset

define WAN_IF = "eth0"
define LAN_IF = "eth1"
define LAN_NET = 10.77.0.0/24

table inet filter {
    chain input {
        type filter hook input priority 0;
        policy drop;

        iifname "lo" accept
        iifname $WAN_IF udp sport 67 udp dport 68 accept

        ct state invalid drop
        ct state established,related accept

        ip protocol icmp accept

        iifname $LAN_IF ip saddr $LAN_NET tcp dport 22 accept
    }

    chain forward {
        type filter hook forward priority 0;
        policy drop;

        ct state invalid drop
        ct state established,related accept

        iifname $LAN_IF oifname $WAN_IF ip saddr $LAN_NET accept
    }

    chain output {
        type filter hook output priority 0;
        policy accept;
    }
}

table ip nat {
    chain postrouting {
        type nat hook postrouting priority 100;
        policy accept;

        ip saddr $LAN_NET oifname $WAN_IF masquerade
    }
}
EOF
```

## 2.7 Validare la sintassi prima di applicare

```bash
sudo nft -c -f /etc/nftables.conf
sudo nft -f /etc/nftables.conf
sudo nft list ruleset
```

## 2.8 Verificare SSH prima di rendere il firewall persistente

```powershell
Test-NetConnection 10.77.0.1 -Port 22
```

## 2.9 Rendere nftables persistente e provare un reboot

```bash
sudo systemctl enable nftables.service
sudo systemctl restart nftables.service

systemctl is-enabled nftables
systemctl is-active nftables
sudo nft list ruleset
```

```bash
sudo reboot
```

```bash
sysctl net.ipv4.ip_forward
systemctl is-enabled nftables
systemctl is-active nftables
ip -br addr
ip route
sudo nft list ruleset
```

## 2.10 Creare linux-client01 senza percorsi alternativi

```powershell
& {
$VMName = 'linux-client01'
$VHD = 'E:\Hyper-V\VHDX\linux-client01.vhdx'
$ISO = 'E:\Hyper-V\ISO\ubuntu-24.04.5-live-server-amd64.iso'

New-VM `
  -Name $VMName `
  -Generation 2 `
  -MemoryStartupBytes 2GB `
  -NewVHDPath $VHD `
  -NewVHDSizeBytes 20GB `
  -SwitchName 'LAB-LAN'

Set-VMProcessor -VMName $VMName -Count 2
Set-VMMemory -VMName $VMName `
  -DynamicMemoryEnabled $true `
  -MinimumBytes 1GB `
  -StartupBytes 2GB `
  -MaximumBytes 4GB

Set-VMFirmware -VMName $VMName `
  -EnableSecureBoot On `
  -SecureBootTemplate 'MicrosoftUEFICertificateAuthority'

Add-VMDvdDrive -VMName $VMName -Path $ISO
$dvd = Get-VMDvdDrive -VMName $VMName
Set-VMFirmware -VMName $VMName -FirstBootDevice $dvd
Set-VM -Name $VMName -AutomaticCheckpointsEnabled $false
}
```

```powershell
Get-VMNetworkAdapter -VMName 'linux-client01' |
Select-Object Name,SwitchName,MacAddress
```

## 2.12 Verifica end-to-end: ogni comando isola uno strato

```bash
ip -br addr
ip route
ping -c 3 10.77.0.1
ping -c 3 1.1.1.1
getent hosts archive.ubuntu.com
curl -I https://archive.ubuntu.com
```

## 2.13 Osservare il traffico su fw01 con tcpdump

```bash
sudo tcpdump -ni eth1 host 10.77.0.101
```

## 2.14 Salvare il punto stabile

```powershell
Checkpoint-VM -Name 'fw01' `
  -SnapshotName 'ROUTER-FIREWALL-VALIDATED'
Checkpoint-VM -Name 'linux-client01' `
  -SnapshotName 'LAB-LAN-CLIENT-VALIDATED'

Get-VMSnapshot -VMName 'fw01','linux-client01' |
Select-Object VMName,Name,CreationTime
```

## 2.16 Troubleshooting per percorso

```bash
sysctl net.ipv4.ip_forward
ip -br addr
ip route
sudo nft list ruleset
systemctl status nftables --no-pager
sudo journalctl -u nftables --no-pager
sudo tcpdump -ni eth1
```

## 2.17 Esercizio – Lo stesso firewall con iptables

```bash
iptables --version
sudo update-alternatives --display iptables
```

```bash
#!/bin/bash
set -euo pipefail

WAN_IF="eth0"
LAN_IF="eth1"
LAN_NET="10.77.0.0/24"

if [ "$(id -u)" -ne 0 ]; then
    echo "Eseguire come root."
    exit 1
fi

iptables-restore <<EOF
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -i lo -j ACCEPT
-A INPUT -i ${WAN_IF} -p udp --sport 67 --dport 68 -j ACCEPT
-A INPUT -m conntrack --ctstate INVALID -j DROP
-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -i ${LAN_IF} -s ${LAN_NET} -p tcp --dport 22 -j ACCEPT
-A FORWARD -m conntrack --ctstate INVALID -j DROP
-A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
-A FORWARD -i ${LAN_IF} -o ${WAN_IF} -s ${LAN_NET} -j ACCEPT
COMMIT
*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s ${LAN_NET} -o ${WAN_IF} -j MASQUERADE
COMMIT
EOF
```

```bash
sudo chmod 750 /usr/local/sbin/fw01-iptables.sh
sudo systemctl disable --now nftables
sudo nft flush ruleset
sudo /usr/local/sbin/fw01-iptables.sh

sudo iptables -L -n -v
sudo iptables -t nat -L -n -v
sudo iptables-save
sudo nft list ruleset
```
