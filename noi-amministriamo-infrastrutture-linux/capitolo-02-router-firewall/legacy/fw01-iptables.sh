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
