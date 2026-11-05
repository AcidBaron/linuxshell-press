# Capitolo 5 – VLAN, segmentazione e reti multiple — comandi e configurazioni
> Estratto operativo dal master `cap5_vlan.docx`. I blocchi sono riportati nell'ordine del capitolo.

## 5.2 Architettura scelta e piano di indirizzamento

```bash
Default Switch
      |
  eth0 / WAN
    [fw01]
      |\
      | \__ eth2 / VLAN-TRUNK -> eth2.10 -> 10.77.10.1/24
      |                          -> eth2.20 -> 10.77.20.1/24
      |
  eth1 / LAN -> 10.77.0.1/24 -> management untagged
```

## 5.3 Inventario pre-VLAN: fotografare prima di cambiare

```powershell
Get-VMNetworkAdapterVlan -VMName fw01,infra01,linux-client01 |
    Format-Table -AutoSize

ip -br link
ip -br -4 addr
ip -4 route
ip -d link show type vlan
sudo nft list ruleset
```

## 5.4 Access e trunk in Hyper-V

```powershell
Checkpoint-VM -Name "fw01" -SnapshotName "CH5-PRE-VLAN"

Add-VMNetworkAdapter `
    -VMName "fw01" `
    -SwitchName "LAB-LAN" `
    -Name "VLAN-TRUNK"

Set-VMNetworkAdapterVlan `
    -VMName "fw01" `
    -VMNetworkAdapterName "VLAN-TRUNK" `
    -Trunk `
    -AllowedVlanIdList "10,20" `
    -NativeVlanId 0
```

## 5.5 Identificare la nuova NIC dentro Linux

```bash
ip -br link
ip -d link
ip -br -4 addr
ip -4 route
```

## 5.6 Creare le subinterfacce 802.1Q con Netplan

```bash
network:
  version: 2

  ethernets:
    eth0:
      dhcp4: true

    eth1:
      addresses:
        - 10.77.0.1/24

    eth2:
      dhcp4: false
      dhcp6: false

  vlans:
    eth2.10:
      id: 10
      link: eth2
      addresses:
        - 10.77.10.1/24

    eth2.20:
      id: 20
      link: eth2
      addresses:
        - 10.77.20.1/24
```

```bash
sudo netplan generate
sudo netplan try --timeout 60

ip -d link show type vlan
ip -br -4 addr
ip -4 route
```

## 5.7 Creare i client VLAN dalla Golden VM

```powershell
& "E:\Hyper-V\Scripts\New-LabLinuxVM.ps1" `
    -Name "vlan10-client01" `
    -IPAddress "10.77.10.101" `
    -Gateway "10.77.10.1"
```

```bash
sudo /usr/local/sbin/generalize-lab-clone.sh \
    vlan10-client01 \
    10.77.10.101/24 \
    10.77.10.1 \
    eth0 \
    ubuntu2404-base \
    10.77.0.100 \
    10.77.0.10
```

```powershell
Set-ExecutionPolicy `
    -Scope CurrentUser `
    -ExecutionPolicy RemoteSigned `
    -Force

Get-ExecutionPolicy -List
```

## 5.8 Configurare le porte Access per i client

```powershell
Set-VMNetworkAdapterVlan `
    -VMName "vlan10-client01" `
    -Access `
    -VlanId 10

Set-VMNetworkAdapterVlan `
    -VMName "vlan20-client01" `
    -Access `
    -VlanId 20
```

```powershell
Get-VMNetworkAdapterVlan `
    -VMName "fw01","vlan10-client01","vlan20-client01" |
    Format-Table -AutoSize
```

## 5.9 Primo test dei client: raggiungere soltanto il gateway

```bash
hostname
ip -br -4 addr
ip -4 route
ping -c 3 10.77.10.1
```

## 5.11 Disegnare una policy minima con nftables

```conf
define VLAN10_IF = "eth2.10"
define VLAN20_IF = "eth2.20"
define VLAN10_NET = 10.77.10.0/24
define VLAN20_NET = 10.77.20.0/24
define DNS_SERVER = 10.77.0.10

# estratto della chain forward
ct state invalid drop
ct state established,related accept

iifname $VLAN10_IF oifname $LAN_IF ip saddr $VLAN10_NET ip daddr $DNS_SERVER udp dport 53 accept
iifname $VLAN10_IF oifname $LAN_IF ip saddr $VLAN10_NET ip daddr $DNS_SERVER tcp dport 53 accept
iifname $VLAN20_IF oifname $LAN_IF ip saddr $VLAN20_NET ip daddr $DNS_SERVER udp dport 53 accept
iifname $VLAN20_IF oifname $LAN_IF ip saddr $VLAN20_NET ip daddr $DNS_SERVER tcp dport 53 accept

iifname $VLAN10_IF oifname $WAN_IF ip saddr $VLAN10_NET accept
iifname $VLAN20_IF oifname $WAN_IF ip saddr $VLAN20_NET accept
```

```bash
# estratto NAT
ip saddr $VLAN10_NET oifname $WAN_IF masquerade
ip saddr $VLAN20_NET oifname $WAN_IF masquerade
```

```bash
sudo nft -c -f /etc/nftables.conf
echo "nft check rc=$?"
sudo nft -f /etc/nftables.conf
sudo nft list ruleset
```

## 5.13 Estendere l’ACL BIND senza aprire la management LAN

```conf
acl "lab_clients" {
    127.0.0.1;
    10.77.0.0/24;
    10.77.10.0/24;
    10.77.20.0/24;
};
```

```bash
sudo named-checkconf
sudo systemctl reload named
systemctl is-active named
```

## 5.14 Verifica finale della segmentazione

```bash
ping -c 2 10.77.10.1
ping -c 2 -W 2 1.1.1.1
dig @10.77.0.10 infra01.lab.test A +time=3 +tries=1 +noall +comments +answer
curl -4 -sS -o /dev/null -w 'HTTP status: %{http_code}\n' https://ubuntu.com
ping -c 2 -W 2 10.77.20.101
ping -c 2 -W 2 10.77.0.101
timeout 3 bash -c 'echo >/dev/tcp/10.77.0.10/22'
```

## 5.15 Estendere il DNS alle nuove reti

```bash
vlan10-client01  IN  A  10.77.10.101
vlan20-client01  IN  A  10.77.20.101
```

```conf
zone "10.77.10.in-addr.arpa" {
    type primary;
    file "/etc/bind/db.10.77.10";
};

zone "20.77.10.in-addr.arpa" {
    type primary;
    file "/etc/bind/db.10.77.20";
};
```

```bash
sudo named-checkzone lab.test /etc/bind/db.lab.test
sudo named-checkzone 10.77.10.in-addr.arpa /etc/bind/db.10.77.10
sudo named-checkzone 20.77.10.in-addr.arpa /etc/bind/db.10.77.20
sudo named-checkconf -z
```

## 5.16 Differenze fra Ubuntu, RHEL/Fedora e configurazioni legacy

```bash
# RHEL/Fedora: esempio equivalente per VLAN 10
nmcli connection add type vlan \
    con-name vlan10 \
    ifname vlan10 \
    vlan.parent eth2 \
    vlan.id 10

nmcli connection modify vlan10 \
    ipv4.addresses 10.77.10.1/24 \
    ipv4.method manual

nmcli connection up vlan10
```

```bash
sudo ip link add link eth2 name eth2.10 type vlan id 10
sudo ip addr add 10.77.10.1/24 dev eth2.10
sudo ip link set eth2 up
sudo ip link set eth2.10 up
ip -d link show eth2.10
```

```bash
# Esempio storico Debian/Ubuntu con ifupdown
auto eth2.10
iface eth2.10 inet static
    address 10.77.10.1/24
    vlan-raw-device eth2

# Esempio storico con vconfig
sudo vconfig add eth2 10
```

## 5.18 Checkpoint e stato validato

```bash
CH5-VLAN-SEGMENTATION-VALIDATED   -> fw01
CH5-DNS-VLAN-VALIDATED            -> infra01
CH5-VLAN10-CLIENT-VALIDATED        -> vlan10-client01
CH5-VLAN20-CLIENT-VALIDATED        -> vlan20-client01
```

## 5.20 Chiediamo all’IA

```bash
SYSTEM:
Sei un senior Linux network engineer specializzato in 802.1Q, Hyper-V,
Netplan, nftables e BIND9. Analizza soltanto le evidenze fornite.
Non assumere che una VLAN funzionante implichi routing autorizzato.
Separa sempre la diagnosi in questi livelli:
1. porta Access/Trunk e tag 802.1Q;
2. interfacce, indirizzi e routing Linux;
3. forwarding e NAT;
4. policy nftables;
5. ACL del servizio applicativo;
6. DNS e risoluzione dei nomi.

Per ogni ipotesi indica:
- evidenza che la sostiene;
- comando di verifica non distruttivo;
- risultato atteso;
- modifica minima solo dopo la verifica;
- rollback.
Non proporre flush del firewall, policy accept generiche o disabilitazioni
di sicurezza come prima soluzione.

USER:
Topologia: management 10.77.0.0/24, VLAN10 10.77.10.0/24,
VLAN20 10.77.20.0/24. fw01 è il router. I client raggiungono il gateway
locale ma non un servizio atteso. Ti fornisco ip -d link, ip route,
nft list ruleset, output dig e log del servizio. Individua il primo layer
che fallisce e prepara una procedura di diagnosi ordinata.
```

## A.1 fw01 – /etc/netplan/50-cloud-init.yaml

```bash
network:
  version: 2

  ethernets:
    eth0:
      dhcp4: true

    eth1:
      addresses:
        - 10.77.0.1/24

    eth2:
      dhcp4: false
      dhcp6: false

  vlans:
    eth2.10:
      id: 10
      link: eth2
      addresses:
        - 10.77.10.1/24

    eth2.20:
      id: 20
      link: eth2
      addresses:
        - 10.77.20.1/24
```

## A.2 fw01 – /etc/nftables.conf

```bash
#!/usr/sbin/nft -f

flush ruleset

define WAN_IF = "eth0"
define LAN_IF = "eth1"
define VLAN10_IF = "eth2.10"
define VLAN20_IF = "eth2.20"

define LAN_NET = 10.77.0.0/24
define VLAN10_NET = 10.77.10.0/24
define VLAN20_NET = 10.77.20.0/24

define DNS_SERVER = 10.77.0.10

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

        iifname $VLAN10_IF oifname $LAN_IF ip saddr $VLAN10_NET ip daddr $DNS_SERVER udp dport 53 accept
        iifname $VLAN10_IF oifname $LAN_IF ip saddr $VLAN10_NET ip daddr $DNS_SERVER tcp dport 53 accept

        iifname $VLAN20_IF oifname $LAN_IF ip saddr $VLAN20_NET ip daddr $DNS_SERVER udp dport 53 accept
        iifname $VLAN20_IF oifname $LAN_IF ip saddr $VLAN20_NET ip daddr $DNS_SERVER tcp dport 53 accept

        iifname $VLAN10_IF oifname $WAN_IF ip saddr $VLAN10_NET accept
        iifname $VLAN20_IF oifname $WAN_IF ip saddr $VLAN20_NET accept
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
        ip saddr $VLAN10_NET oifname $WAN_IF masquerade
        ip saddr $VLAN20_NET oifname $WAN_IF masquerade
    }
}
```

## A.3 infra01 – /etc/bind/named.conf.options

```conf
acl "lab_clients" {
    127.0.0.1;
    10.77.0.0/24;
    10.77.10.0/24;
    10.77.20.0/24;
};

options {
    directory "/var/cache/bind";

    listen-on {
        127.0.0.1;
        10.77.0.10;
    };

    listen-on-v6 {
        none;
    };

    recursion yes;

    allow-query {
        lab_clients;
    };

    allow-recursion {
        lab_clients;
    };

    allow-query-cache {
        lab_clients;
    };

    forwarders {
        1.1.1.1;
        8.8.8.8;
    };

    forward only;

    dnssec-validation no;

    minimal-responses yes;
};
```

## A.4 infra01 – /etc/bind/named.conf.local

```conf
zone "lab.test" {
    type primary;
    file "/etc/bind/db.lab.test";
};

zone "0.77.10.in-addr.arpa" {
    type primary;
    file "/etc/bind/db.10.77.0";
};

zone "10.77.10.in-addr.arpa" {
    type primary;
    file "/etc/bind/db.10.77.10";
};

zone "20.77.10.in-addr.arpa" {
    type primary;
    file "/etc/bind/db.10.77.20";
};
```

## A.5 infra01 – /etc/bind/db.lab.test

```bash
$TTL 3600
@   IN  SOA infra01.lab.test. hostmaster.lab.test. (
        2026101601 ; serial
        3600       ; refresh
        900        ; retry
        604800     ; expire
        300        ; negative cache TTL
)

    IN  NS  infra01.lab.test.

fw01            IN  A      10.77.0.1
infra01         IN  A      10.77.0.10
linux-client01  IN  A      10.77.0.101
dns             IN  CNAME  infra01.lab.test.
vlan10-client01 IN  A      10.77.10.101
vlan20-client01 IN  A      10.77.20.101
```

## A.6 infra01 – /etc/bind/db.10.77.10

```bash
$TTL 3600
@   IN  SOA infra01.lab.test. hostmaster.lab.test. (
        2026101601 ; serial
        3600       ; refresh
        900        ; retry
        604800     ; expire
        300        ; negative cache TTL
)

    IN  NS  infra01.lab.test.

101     IN  PTR vlan10-client01.lab.test.
```

## A.7 infra01 – /etc/bind/db.10.77.20

```bash
$TTL 3600
@   IN  SOA infra01.lab.test. hostmaster.lab.test. (
        2026101601 ; serial
        3600       ; refresh
        900        ; retry
        604800     ; expire
        300        ; negative cache TTL
)

    IN  NS  infra01.lab.test.

101     IN  PTR vlan20-client01.lab.test.
```

## A.8 vlan10-client01 – /etc/netplan/10-lab-static.yaml

```bash
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: false
      addresses:
        - "10.77.10.101/24"
      nameservers:
        addresses:
          - 10.77.0.10
        search: [lab.test]
      routes:
        - to: default
          via: "10.77.10.1"
```

## A.9 vlan20-client01 – /etc/netplan/10-lab-static.yaml

```bash
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: false
      addresses:
        - "10.77.20.101/24"
      nameservers:
        addresses:
          - 10.77.0.10
        search: [lab.test]
      routes:
        - to: default
          via: "10.77.20.1"
```
