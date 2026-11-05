# Rollback – Capitolo 2

## Forwarding IPv4

Rimuovere il file locale e riportare il valore runtime a zero:

```bash
sudo rm -f /etc/sysctl.d/99-fw01-router.conf
sudo sysctl -w net.ipv4.ip_forward=0
```

## nftables

Prima della modifica il laboratorio conserva `/etc/nftables.conf.original`:

```bash
sudo cp -a /etc/nftables.conf.original /etc/nftables.conf
sudo nft -c -f /etc/nftables.conf
sudo systemctl restart nftables
```

## Checkpoint Hyper-V

Per un ritorno completo usare il checkpoint `BASE-OS-INSTALLED`. I checkpoint finali del capitolo sono `ROUTER-FIREWALL-VALIDATED` e `LAB-LAN-CLIENT-VALIDATED`.
