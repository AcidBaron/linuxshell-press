#!/bin/bash
# CH23: remove only the temporary Corosync test rules (not production firewall policy).
iptables -D INPUT -s 10.77.0.101 \
  -p udp --dport 5405 -j DROP 2>/dev/null || true
iptables -D OUTPUT -d 10.77.0.101 \
  -p udp --dport 5405 -j DROP 2>/dev/null || true
