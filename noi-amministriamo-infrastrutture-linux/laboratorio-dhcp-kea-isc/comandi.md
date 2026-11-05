# Laboratorio parallelo – DHCP con Kea: lease, reservation e compatibilità ISC DHCP legacy — comandi e configurazioni
> Estratto operativo dal master `Laboratorio_parallelo_DHCP_Kea_ISC_legacy.docx`. I blocchi sono riportati nell'ordine del capitolo.

## D.2 Preflight, indirizzo del server e provisioning di dhcp01

```bash
echo "=== DHCP LAB PREFLIGHT - FW01 ==="
ip -br addr
ip route
ping -c 2 -W 1 10.77.0.30 || true
sudo arping -D -I eth1 -c 3 10.77.0.30
echo "arping_exit=$?"
sudo ss -lunp | grep -E ':(67|68)\b' || true
```

```powershell
cd E:\Hyper-V\Scripts
.\New-LabLinuxVM-R2_2.ps1 `
    -Name "dhcp01" `
    -IPAddress "10.77.0.30" `
    -Prefix 24 `
    -Gateway "10.77.0.1" `
    -DNS1 "10.77.0.10" `
    -SearchDomain "lab.test" `
    -FinalSwitch "LAB-LAN" `
    -NonInteractive
```

## D.3 Registrare dhcp01 nel DNS BIND9

```bash
sudo cp -a /etc/bind/db.lab.test /etc/bind/db.lab.test.pre-dhcp01
sudo cp -a /etc/bind/db.10.77.0 /etc/bind/db.10.77.0.pre-dhcp01

# record aggiunti
# dhcp01  IN  A    10.77.0.30
# 30      IN  PTR  dhcp01.lab.test.
```

## D.4 Preparare dhcp-client01 senza perdere il rollback storico

```powershell
Checkpoint-VM -Name "r2-test01" -SnapshotName "PRE-DHCP-CLIENT-REUSE"
Rename-VM -Name "r2-test01" -NewName "dhcp-client01"
Connect-VMNetworkAdapter -VMName "dhcp-client01" -Name "LAN" -SwitchName "LAB-LAN"
Set-VMNetworkAdapterVlan -VMName "dhcp-client01" -VMNetworkAdapterName "LAN" -Untagged
```

```bash
sudo cp -a /etc/hostname /etc/hostname.pre-dhcp-client
sudo cp -a /etc/hosts /etc/hosts.pre-dhcp-client
sudo cp -a /etc/netplan/10-lab-static.yaml /etc/netplan/10-lab-static.yaml.pre-dhcp-client
sudo hostnamectl set-hostname dhcp-client01
sudo sed -i 's/r2-test01/dhcp-client01/g' /etc/hosts
sudo rm /etc/netplan/10-lab-static.yaml

sudo tee /etc/netplan/10-lab-dhcp.yaml > /dev/null <<'EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: true
      dhcp6: false
      accept-ra: true
      optional: true
EOF

sudo chmod 600 /etc/netplan/10-lab-dhcp.yaml
sudo netplan generate
sudo netplan get
```

## D.5 Failure case controllato: client DHCP senza server

```bash
# su fw01
sudo timeout 60 tcpdump -ni eth1 -e -vvv 'udp port 67 or udp port 68'

# sul client, dalla console Hyper-V
sudo systemctl restart systemd-networkd
```

## D.6 Installare Kea DHCPv4

```bash
sudo apt update
sudo apt install -y kea-dhcp4-server
kea-dhcp4 -V
dpkg -l kea-dhcp4-server | grep '^ii'
sudo systemctl stop kea-dhcp4-server
sudo cp -a /etc/kea/kea-dhcp4.conf /etc/kea/kea-dhcp4.conf.package-default
```

```json
{
  "Dhcp4": {
    "interfaces-config": {
      "interfaces": [ "eth0" ]
    },
    "lease-database": {
      "type": "memfile",
      "persist": true,
      "lfc-interval": 3600
    },
    "renew-timer": 900,
    "rebind-timer": 1800,
    "valid-lifetime": 3600,
    "subnet4": [
      {
        "id": 1,
        "subnet": "10.77.0.0/24",
        "pools": [
          { "pool": "10.77.0.102 - 10.77.0.199" }
        ],
        "option-data": [
          { "name": "routers", "data": "10.77.0.1" },
          { "name": "domain-name-servers", "data": "10.77.0.10" },
          { "name": "domain-name", "data": "lab.test" }
        ]
      }
    ]
  }
}
```

```bash
sudo kea-dhcp4 -t /etc/kea/kea-dhcp4.conf
echo "kea_config_exit=$?"
sudo systemctl enable --now kea-dhcp4-server
systemctl is-enabled kea-dhcp4-server
systemctl is-active kea-dhcp4-server
sudo ss -lunp | grep ':67\b'
```

## D.8 Rinnovo del lease e persistenza

```bash
# server
sudo timeout 60 tcpdump -ni eth0 -e -vvv 'udp port 67 or udp port 68'

# client
sudo networkctl renew eth0
ip -4 addr show dev eth0
networkctl status eth0 --no-pager
```

## D.9 Reservation: dallo stesso client dinamico a 10.77.0.150

```bash
"host-reservation-identifiers": [
  "hw-address"
],

"reservations": [
  {
    "hw-address": "00:15:5d:01:07:0e",
    "ip-address": "10.77.0.150",
    "hostname": "dhcp-client01"
  }
]
```

## D.10 Stato stabile Kea prima del percorso legacy

```bash
sudo cp -a /etc/kea/kea-dhcp4.conf /etc/kea/kea-dhcp4.conf.KEA-STABLE-FINAL
```

## D.12 Switch controllato Kea OFF → ISC DHCP ON

```bash
sudo systemctl disable --now kea-dhcp4-server
systemctl is-enabled kea-dhcp4-server || true
systemctl is-active kea-dhcp4-server || true
sudo ss -lunp | grep ':67\b' || echo "UDP/67 free"

sudo apt update
sudo apt install -y isc-dhcp-server
dhcpd --version
```

```conf
authoritative;
ddns-update-style none;

default-lease-time 3600;
max-lease-time 3600;

option domain-name "lab.test";
option domain-name-servers 10.77.0.10;

subnet 10.77.0.0 netmask 255.255.255.0 {
    option subnet-mask 255.255.255.0;
    option routers 10.77.0.1;
    option broadcast-address 10.77.0.255;

    range 10.77.0.102 10.77.0.149;
    range 10.77.0.151 10.77.0.199;
}

host dhcp-client01 {
    hardware ethernet 00:15:5d:01:07:0e;
    fixed-address 10.77.0.150;
    option host-name "dhcp-client01";
}
```

## D.13 Reservation legacy: DORA completo e differenza dal lease dinamico

```bash
DHCPDISCOVER from 00:15:5d:01:07:0e via eth0
DHCPOFFER on 10.77.0.150 to 00:15:5d:01:07:0e via eth0
DHCPREQUEST for 10.77.0.150 (10.77.0.30) from 00:15:5d:01:07:0e via eth0
DHCPACK on 10.77.0.150 to 00:15:5d:01:07:0e via eth0
```

## D.14 Pool dinamico ISC DHCP e dhcpd.leases

```bash
lease 10.77.0.102 {
  starts 3 2026/11/04 15:50:37;
  ends 3 2026/11/04 16:50:37;
  cltt 3 2026/11/04 15:50:37;
  binding state active;
  next binding state free;
  rewind binding state free;
  hardware ethernet 00:15:5d:01:07:0e;
  client-hostname "dhcp-client01";
}
```

## D.15 Ripristinare Kea come stato finale

```bash
sudo systemctl disable --now isc-dhcp-server

sudo cmp /etc/kea/kea-dhcp4.conf /etc/kea/kea-dhcp4.conf.KEA-STABLE-FINAL
echo "cmp_exit=$?"

sudo kea-dhcp4 -t /etc/kea/kea-dhcp4.conf
sudo systemctl enable --now kea-dhcp4-server
systemctl is-enabled kea-dhcp4-server
systemctl is-active kea-dhcp4-server
sudo ss -lunp | grep ':67\b'
```

## Appendice A.1 – Configurazione Kea finale

```json
{
  "Dhcp4": {
    "interfaces-config": {
      "interfaces": [ "eth0" ]
    },
    "lease-database": {
      "type": "memfile",
      "persist": true,
      "lfc-interval": 3600
    },
    "renew-timer": 900,
    "rebind-timer": 1800,
    "valid-lifetime": 3600,
    "subnet4": [
      {
        "id": 1,
        "subnet": "10.77.0.0/24",
        "pools": [
          { "pool": "10.77.0.102 - 10.77.0.199" }
        ],
        "option-data": [
          { "name": "routers", "data": "10.77.0.1" },
          { "name": "domain-name-servers", "data": "10.77.0.10" },
          { "name": "domain-name", "data": "lab.test" }
        ],
        "reservations": [
          {
            "hw-address": "00:15:5d:01:07:0e",
            "ip-address": "10.77.0.150",
            "hostname": "dhcp-client01"
          }
        ]
      }
    ],
    "host-reservation-identifiers": [ "hw-address" ]
  }
}
```

## Appendice A.2 – Netplan finale del client

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: true
      dhcp6: false
      accept-ra: true
      optional: true
```

## Appendice A.3 – Rollback operativo

```bash
sudo systemctl disable --now isc-dhcp-server
sudo cp -a /etc/kea/kea-dhcp4.conf.KEA-STABLE-FINAL /etc/kea/kea-dhcp4.conf
sudo kea-dhcp4 -t /etc/kea/kea-dhcp4.conf
sudo systemctl enable --now kea-dhcp4-server
systemctl is-active kea-dhcp4-server
sudo ss -lunp | grep ':67\b'
```
