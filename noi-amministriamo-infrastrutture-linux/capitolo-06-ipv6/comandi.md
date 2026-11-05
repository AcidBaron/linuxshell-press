# Capitolo 6 – IPv6 nell’infrastruttura moderna — comandi e configurazioni
> Estratto operativo dal master `Capitolo_06_IPv6_nell_infrastruttura_moderna.docx`. I blocchi sono riportati nell'ordine del capitolo.

## 6.3 Architettura e piano ULA del laboratorio

```bash
ULA di laboratorio: fd3a:7b4c:2d91::/48

Management LAN: fd3a:7b4c:2d91:1::/64
VLAN 10:        fd3a:7b4c:2d91:10::/64
VLAN 20:        fd3a:7b4c:2d91:20::/64
```

```bash
Default Switch / WAN IPv4
        |
      eth0
     [fw01]
      / | \
     /  |  \
 eth1   |   eth2 trunk
   |    |      |
   |    |      +-- eth2.10  fd3a:7b4c:2d91:10::1/64
   |    |      +-- eth2.20  fd3a:7b4c:2d91:20::1/64
   |
   +-- fd3a:7b4c:2d91:1::1/64
          |
       infra01
 fd3a:7b4c:2d91:1::10/64
```

## 6.4 Baseline: partire dai link-local

```bash
ip -br -6 addr
ip -6 route
ip -6 neigh
sysctl net.ipv6.conf.all.forwarding
```

```bash
ping -6 -c 3 fe80::215:5dff:fe01:703%eth0
ip -6 neigh show dev eth0
```

## 6.5 Failure case: NDP bloccato dal firewall

```bash
sudo tcpdump -ni eth1 -vv 'icmp6 and (ip6[40] == 135 or ip6[40] == 136)'
```

```bash
iifname { $LAN_IF, $VLAN10_IF, $VLAN20_IF } \
    icmpv6 type { \
        nd-router-solicit, \
        nd-neighbor-solicit, \
        nd-neighbor-advert \
    } counter accept
```

## 6.6 ULA statici sulla management e un errore di notazione

```bash
fw01 eth1:   fd3a:7b4c:2d91:1::1/64
infra01 eth0: fd3a:7b4c:2d91:1::10/64
```

```bash
Errato:   fd3a:7b4c:2d91::1:1/64
Corretto: fd3a:7b4c:2d91:1::1/64
```

## 6.7 Abilitare il forwarding IPv6 in modo persistente

```bash
sudo tee /etc/sysctl.d/60-ipv6-router.conf >/dev/null <<'EOF'
net.ipv6.conf.all.forwarding=1
EOF

sudo sysctl --system
sysctl net.ipv6.conf.all.forwarding
```

## 6.8 Router Advertisement e SLAAC con radvd

```conf
interface eth1
{
    AdvSendAdvert on;
    MinRtrAdvInterval 10;
    MaxRtrAdvInterval 30;

    AdvManagedFlag off;
    AdvOtherConfigFlag off;
    AdvDefaultLifetime 0;

    prefix fd3a:7b4c:2d91:1::/64
    {
        AdvOnLink on;
        AdvAutonomous on;
        AdvValidLifetime 3600;
        AdvPreferredLifetime 1800;
    };
};
```

```bash
sudo radvd -c -C /etc/radvd.conf
sudo systemctl enable --now radvd
systemctl is-active radvd
```

```bash
ip -br -6 addr show eth0
ip -6 route

sudo timeout 40 tcpdump -ni eth0 -vv -c 1 \
  'icmp6 and ip6[40] == 134'
```

## 6.9 Failure case: il router consumava i propri RA

```bash
eth1:
  dhcp4: false
  dhcp6: false
  accept-ra: false
  addresses:
    - 10.77.0.1/24
    - fd3a:7b4c:2d91:1::1/64
```

## 6.10 Estendere IPv6 alle VLAN 10 e 20

```bash
eth2.10:  10.77.10.1/24  +  fd3a:7b4c:2d91:10::1/64
eth2.20:  10.77.20.1/24  +  fd3a:7b4c:2d91:20::1/64
```

## 6.11 Annunciare la ULA /48 senza una default route

```bash
route fd3a:7b4c:2d91::/48
{
    AdvRoutePreference medium;
    AdvRouteLifetime 1800;
};
```

```bash
fd3a:7b4c:2d91::/48 \
    via fe80::215:5dff:fe01:706 \
    dev eth0 proto ra
```

## 6.12 Dimostrare che routing e firewall sono due cose diverse

```bash
iifname $VLAN10_IF oifname $VLAN20_IF \
    ip6 saddr $VLAN10_6_NET \
    ip6 daddr $VLAN20_6_NET \
    counter drop

iifname $VLAN20_IF oifname $VLAN10_IF \
    ip6 saddr $VLAN20_6_NET \
    ip6 daddr $VLAN10_6_NET \
    counter drop
```

## 6.13 Rendere nftables realmente persistente

```bash
sudo nft -c -f /etc/nftables.conf
sudo systemctl reload nftables
sudo nft -a list chain inet filter input
sudo nft -a list chain inet filter forward
```

## 6.14 Trasformare infra01 in server IPv6 deterministico

```bash
addresses:
  - 10.77.0.10/24
  - fd3a:7b4c:2d91:1::10/64

routes:
  - to: default
    via: 10.77.0.1
  - to: fd3a:7b4c:2d91::/48
    via: fd3a:7b4c:2d91:1::1
```

## 6.15 Portare BIND9 in dual-stack

```conf
acl "lab_clients" {
    127.0.0.1;
    ::1;

    10.77.0.0/24;
    10.77.10.0/24;
    10.77.20.0/24;

    fd3a:7b4c:2d91:1::/64;
    fd3a:7b4c:2d91:10::/64;
    fd3a:7b4c:2d91:20::/64;
};

listen-on-v6 {
    ::1;
    fd3a:7b4c:2d91:1::10;
};
```

```bash
sudo named-checkconf
sudo systemctl restart bind9
sudo ss -lntup | grep '\:53'
```

```bash
dig -6 @fd3a:7b4c:2d91:1::10 lab.test SOA
dig -6 @fd3a:7b4c:2d91:1::10 example.com A
```

## 6.16 Consentire solo DNS IPv6 dalle VLAN

```bash
iifname $VLAN10_IF oifname $LAN_IF \
    ip6 saddr $VLAN10_6_NET \
    ip6 daddr $DNS6_SERVER udp dport 53 \
    counter accept

iifname $VLAN10_IF oifname $LAN_IF \
    ip6 saddr $VLAN10_6_NET \
    ip6 daddr $DNS6_SERVER tcp dport 53 \
    counter accept
```

## 6.17 Record AAAA e reverse ip6.arpa

```bash
fw01       IN  AAAA  fd3a:7b4c:2d91:1::1
infra01    IN  AAAA  fd3a:7b4c:2d91:1::10
```

```bash
python3 - <<'PY'
import ipaddress

for addr in (
    "fd3a:7b4c:2d91:1::1",
    "fd3a:7b4c:2d91:1::10",
):
    ip = ipaddress.IPv6Address(addr)
    host = ip.exploded.replace(":", "")[16:]
    print(addr, "->", ".".join(reversed(host)))
PY
```

```bash
1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0 IN PTR fw01.lab.test.
0.1.0.0.0.0.0.0.0.0.0.0.0.0.0.0 IN PTR infra01.lab.test.
```

## 6.17.1 Failure case: il backslash nel master file BIND

```bash
sudo named-checkzone lab.test /etc/bind/db.lab.test
sudo named-checkzone \
  1.0.0.0.1.9.d.2.c.4.b.7.a.3.d.f.ip6.arpa \
  /etc/bind/db.fd3a-7b4c-2d91-1
sudo named-checkconf
sudo systemctl reload bind9
```

## 6.19 Verifica della persistenza e reboot

```bash
systemctl is-enabled nftables
systemctl is-enabled radvd
systemctl is-enabled named.service

sudo netplan generate
sudo radvd -c -C /etc/radvd.conf
sudo nft -c -f /etc/nftables.conf
sudo named-checkconf
```

## 6.22 Chiediamo all’IA

```bash
Esempio di prompt:

"Sto diagnosticando una rete IPv6 dual-stack. Il client possiede
fd3a:7b4c:2d91:10::/64 via SLAAC e una route
fd3a:7b4c:2d91::/48 via il link-local del router.
Il ping al gateway locale passa, quello verso un host della VLAN 20 no.
Ti fornisco ip -6 route, ip -6 neigh e nft list chain forward.
Indica in quale livello si ferma il traffico, quali evidenze lo dimostrano
e quali comandi non distruttivi useresti per confermare la diagnosi."
```

## A.1.1 /etc/netplan/50-cloud-init.yaml

```bash
network:
  version: 2

  ethernets:
    eth0:
      dhcp4: true

    eth1:
      dhcp4: false
      dhcp6: false
      accept-ra: false
      addresses:
        - 10.77.0.1/24
        - fd3a:7b4c:2d91:1::1/64

    eth2:
      dhcp4: false
      dhcp6: false

  vlans:
    eth2.10:
      id: 10
      link: eth2
      dhcp6: false
      accept-ra: false
      addresses:
        - 10.77.10.1/24
        - fd3a:7b4c:2d91:10::1/64

    eth2.20:
      id: 20
      link: eth2
      dhcp6: false
      accept-ra: false
      addresses:
        - 10.77.20.1/24
        - fd3a:7b4c:2d91:20::1/64
```

## A.1.2 /etc/sysctl.d/60-ipv6-router.conf

```bash
net.ipv6.conf.all.forwarding=1
```

## A.1.3 /etc/radvd.conf

```conf
interface eth1
{
    AdvSendAdvert on;
    MinRtrAdvInterval 10;
    MaxRtrAdvInterval 30;

    AdvManagedFlag off;
    AdvOtherConfigFlag off;
    AdvDefaultLifetime 0;

    prefix fd3a:7b4c:2d91:1::/64
    {
        AdvOnLink on;
        AdvAutonomous on;
        AdvValidLifetime 3600;
        AdvPreferredLifetime 1800;
    };

    route fd3a:7b4c:2d91::/48
    {
        AdvRoutePreference medium;
        AdvRouteLifetime 1800;
    };
};

interface eth2.10
{
    AdvSendAdvert on;
    MinRtrAdvInterval 10;
    MaxRtrAdvInterval 30;

    AdvManagedFlag off;
    AdvOtherConfigFlag off;
    AdvDefaultLifetime 0;

    prefix fd3a:7b4c:2d91:10::/64
    {
        AdvOnLink on;
        AdvAutonomous on;
        AdvValidLifetime 3600;
        AdvPreferredLifetime 1800;
    };

    route fd3a:7b4c:2d91::/48
    {
        AdvRoutePreference medium;
        AdvRouteLifetime 1800;
    };
};

interface eth2.20
{
    AdvSendAdvert on;
    MinRtrAdvInterval 10;
    MaxRtrAdvInterval 30;

    AdvManagedFlag off;
    AdvOtherConfigFlag off;
    AdvDefaultLifetime 0;

    prefix fd3a:7b4c:2d91:20::/64
    {
        AdvOnLink on;
        AdvAutonomous on;
        AdvValidLifetime 3600;
        AdvPreferredLifetime 1800;
    };

    route fd3a:7b4c:2d91::/48
    {
        AdvRoutePreference medium;
        AdvRouteLifetime 1800;
    };
};
```

## A.1.4 /etc/nftables.conf

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

define LAN6_NET = fd3a:7b4c:2d91:1::/64
define VLAN10_6_NET = fd3a:7b4c:2d91:10::/64
define VLAN20_6_NET = fd3a:7b4c:2d91:20::/64

define DNS_SERVER = 10.77.0.10
define DNS6_SERVER = fd3a:7b4c:2d91:1::10

table inet filter {
    chain input {
        type filter hook input priority 0;
        policy drop;

        iifname "lo" accept

        # DHCP IPv4 sulla WAN
        iifname $WAN_IF udp sport 67 udp dport 68 accept

        # IPv6: Neighbor Discovery e Router Solicitation
        iifname { $LAN_IF, $VLAN10_IF, $VLAN20_IF } \
            icmpv6 type {
                nd-router-solicit,
                nd-neighbor-solicit,
                nd-neighbor-advert
            } counter accept

        # ICMPv6 necessario per error reporting, PMTU e diagnostica
        iifname { $LAN_IF, $VLAN10_IF, $VLAN20_IF } \
            icmpv6 type {
                destination-unreachable,
                packet-too-big,
                time-exceeded,
                parameter-problem,
                echo-request,
                echo-reply
            } counter accept

        ct state invalid drop
        ct state established,related accept

        # ICMP IPv4
        ip protocol icmp accept

        # SSH dalla management LAN IPv4
        iifname $LAN_IF \
            ip saddr $LAN_NET \
            tcp dport 22 accept
    }

    chain forward {
        type filter hook forward priority 0;
        policy drop;

        ct state invalid drop

        # IPv6: segmentazione esplicita VLAN 10 <-> VLAN 20
        iifname $VLAN10_IF \
            oifname $VLAN20_IF \
            ip6 saddr $VLAN10_6_NET \
            ip6 daddr $VLAN20_6_NET \
            counter drop

        iifname $VLAN20_IF \
            oifname $VLAN10_IF \
            ip6 saddr $VLAN20_6_NET \
            ip6 daddr $VLAN10_6_NET \
            counter drop

        ct state established,related accept

        # Management LAN -> Internet
        iifname $LAN_IF \
            oifname $WAN_IF \
            ip saddr $LAN_NET accept

        # VLAN 10 -> DNS centrale IPv4
        iifname $VLAN10_IF \
            oifname $LAN_IF \
            ip saddr $VLAN10_NET \
            ip daddr $DNS_SERVER \
            udp dport 53 accept

        iifname $VLAN10_IF \
            oifname $LAN_IF \
            ip saddr $VLAN10_NET \
            ip daddr $DNS_SERVER \
            tcp dport 53 accept

        # VLAN 20 -> DNS centrale IPv4
        iifname $VLAN20_IF \
            oifname $LAN_IF \
            ip saddr $VLAN20_NET \
            ip daddr $DNS_SERVER \
            udp dport 53 accept

        iifname $VLAN20_IF \
            oifname $LAN_IF \
            ip saddr $VLAN20_NET \
            ip daddr $DNS_SERVER \
            tcp dport 53 accept

        # VLAN 10 -> DNS centrale IPv6
        iifname $VLAN10_IF \
            oifname $LAN_IF \
            ip6 saddr $VLAN10_6_NET \
            ip6 daddr $DNS6_SERVER \
            udp dport 53 counter accept

        iifname $VLAN10_IF \
            oifname $LAN_IF \
            ip6 saddr $VLAN10_6_NET \
            ip6 daddr $DNS6_SERVER \
            tcp dport 53 counter accept

        # VLAN 20 -> DNS centrale IPv6
        iifname $VLAN20_IF \
            oifname $LAN_IF \
            ip6 saddr $VLAN20_6_NET \
            ip6 daddr $DNS6_SERVER \
            udp dport 53 counter accept

        iifname $VLAN20_IF \
            oifname $LAN_IF \
            ip6 saddr $VLAN20_6_NET \
            ip6 daddr $DNS6_SERVER \
            tcp dport 53 counter accept

        # VLAN 10 -> Internet IPv4
        iifname $VLAN10_IF \
            oifname $WAN_IF \
            ip saddr $VLAN10_NET accept

        # VLAN 20 -> Internet IPv4
        iifname $VLAN20_IF \
            oifname $WAN_IF \
            ip saddr $VLAN20_NET accept
    }

    chain output {
        type filter hook output priority 0;
        policy accept;
    }
}

# NAT soltanto IPv4. Nessun NAT66.
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

## A.2.1 /etc/netplan/10-lab-static.yaml

```bash
network:
  version: 2
  renderer: networkd

  ethernets:
    eth0:
      dhcp4: false
      dhcp6: false
      accept-ra: false

      addresses:
        - 10.77.0.10/24
        - fd3a:7b4c:2d91:1::10/64

      nameservers:
        addresses:
          - 1.1.1.1
          - 8.8.8.8
        search: []

      routes:
        - to: default
          via: 10.77.0.1

        - to: fd3a:7b4c:2d91::/48
          via: fd3a:7b4c:2d91:1::1
```

## A.2.2 /etc/bind/named.conf.options

```conf
acl "lab_clients" {
    127.0.0.1;
    ::1;

    10.77.0.0/24;
    10.77.10.0/24;
    10.77.20.0/24;

    fd3a:7b4c:2d91:1::/64;
    fd3a:7b4c:2d91:10::/64;
    fd3a:7b4c:2d91:20::/64;
};

options {
    directory "/var/cache/bind";

    listen-on {
        127.0.0.1;
        10.77.0.10;
    };

    listen-on-v6 {
        ::1;
        fd3a:7b4c:2d91:1::10;
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

## A.2.3 /etc/bind/named.conf.local

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

zone "1.0.0.0.1.9.d.2.c.4.b.7.a.3.d.f.ip6.arpa" {
    type primary;
    file "/etc/bind/db.fd3a-7b4c-2d91-1";
};
```

## A.2.4 /etc/bind/db.lab.test

```bash
$TTL 3600
@   IN  SOA infra01.lab.test. hostmaster.lab.test. (
        2026102201 ; serial
        3600       ; refresh
        900        ; retry
        604800     ; expire
        300        ; negative cache TTL
)

    IN  NS  infra01.lab.test.

fw01            IN  A       10.77.0.1
fw01            IN  AAAA    fd3a:7b4c:2d91:1::1

infra01         IN  A       10.77.0.10
infra01         IN  AAAA    fd3a:7b4c:2d91:1::10

linux-client01  IN  A       10.77.0.101

dns             IN  CNAME   infra01.lab.test.

vlan10-client01 IN  A       10.77.10.101
vlan20-client01 IN  A       10.77.20.101
```

## A.2.5 /etc/bind/db.fd3a-7b4c-2d91-1

```bash
$TTL 3600
@   IN  SOA infra01.lab.test. hostmaster.lab.test. (
        2026102201 ; serial
        3600       ; refresh
        900        ; retry
        604800     ; expire
        300        ; negative cache TTL
)

    IN  NS  infra01.lab.test.

1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0 IN PTR fw01.lab.test.
0.1.0.0.0.0.0.0.0.0.0.0.0.0.0.0 IN PTR infra01.lab.test.
```

## A.4 Comandi di verifica e rollback

```bash
# Netplan
sudo netplan generate
sudo netplan try

# radvd
sudo radvd -c -C /etc/radvd.conf
systemctl is-active radvd

# nftables
sudo nft -c -f /etc/nftables.conf
sudo systemctl reload nftables

# BIND
sudo named-checkconf
sudo named-checkzone lab.test /etc/bind/db.lab.test
sudo named-checkzone \
  1.0.0.0.1.9.d.2.c.4.b.7.a.3.d.f.ip6.arpa \
  /etc/bind/db.fd3a-7b4c-2d91-1
sudo systemctl reload bind9
```
