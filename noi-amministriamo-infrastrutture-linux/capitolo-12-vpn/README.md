# Capitolo 12 – VPN con WireGuard e OpenVPN

Materiale operativo associato al Capitolo 12 di **Noi Amministriamo Infrastrutture Linux** — Linuxshell Press.

Il libro resta la fonte editoriale e didattica autorevole. I file qui pubblicati derivano dalla configurazione realmente validata nel laboratorio del Capitolo 12; gli esempi che conterrebbero segreti usano placeholder espliciti.

## Topologia validata

- Host Windows / Hyper-V: `VPN-WAN = 10.250.0.1/24`, WinNAT `VPN-WAN-NAT`.
- `fw01 eth0 = 10.250.0.2/24`.
- WireGuard: `wg0 = 10.99.10.1/24`, UDP/51820; client01 `10.99.10.2`.
- OpenVPN: `tun0 = 10.99.20.1/24`, UDP/1194; client01 `10.99.20.2`.
- OpenVPN client02: `10.99.20.3` prima della revoca.
- `infra01 = 10.77.0.10`, DNS BIND.
- Checkpoint finale: `CH12-VPN-FINAL-VALIDATED`.

## Tre scenari

### 1. Laboratorio realmente validato

Il PC Windows del laboratorio è collegato anche direttamente alla LAB-LAN. Per dimostrare il percorso VPN senza deviare le normali sessioni amministrative, il client instrada nel tunnel soltanto `infra01`.

WireGuard:

```ini
AllowedIPs = 10.99.10.0/24, 10.77.0.10/32
```

OpenVPN:

```text
push "route 10.77.0.10 255.255.255.255"
```

### 2. Client realmente remoto

Un client esterno alla sede non possiede una connessione diretta alla LAB-LAN e può normalmente ricevere l'intera rete interna necessaria.

WireGuard:

```ini
AllowedIPs = 10.99.10.0/24, 10.77.0.0/24
```

OpenVPN:

```text
push "route 10.77.0.0 255.255.255.0"
```

Il tunnel non sostituisce le ACL applicative: firewall, BIND e gli altri servizi devono autorizzare esplicitamente le subnet VPN.

### 3. Server VPN dedicato

La variante con `vpn01` separato da `fw01` è descritta nel libro. Con routing puro il router deve conoscere le reti VPN attraverso `vpn01`; con NAT sul server VPN il return path è più semplice, ma i server interni non vedono più l'indirizzo reale del client.

## Comandi Hyper-V usati nel laboratorio

I comandi brevi restano anche nel libro e sono riportati qui come riferimento operativo; non esiste uno script `create-vpn-wan.ps1` separato.

```powershell
New-VMSwitch `
    -Name "VPN-WAN" `
    -SwitchType Internal

$IfIndex = (
    Get-NetAdapter -Name "vEthernet (VPN-WAN)"
).ifIndex

New-NetIPAddress `
    -InterfaceIndex $IfIndex `
    -IPAddress 10.250.0.1 `
    -PrefixLength 24

New-NetNat `
    -Name "VPN-WAN-NAT" `
    -InternalIPInterfaceAddressPrefix 10.250.0.0/24

Connect-VMNetworkAdapter `
    -VMName "fw01" `
    -Name "WAN" `
    -SwitchName "VPN-WAN"
```

## File

- `linux/90-ch12-vpn-wan.yaml` — Netplan realmente usato su `fw01`.
- `wireguard/wg0.conf.example` — `wg0.conf` reale sanificato.
- `wireguard/windows-client.conf.example` — profilo Windows reale sanificato.
- `wireguard/nftables-wireguard.snippet` — regole WireGuard estratte dallo stato finale di `/etc/nftables.conf`.
- `openvpn/ch12.conf` — configurazione server realmente usata.
- `openvpn/windows-client.ovpn.example` — struttura del profilo client validato con placeholder per materiale crittografico.
- `openvpn/nftables-openvpn.snippet` — regole OpenVPN estratte dallo stato finale di `/etc/nftables.conf`.
- `openvpn/README-PKI.md` — emissione, secondo client e revoca.
- `bind/vpn-acl.snippet` — ACL `lab_clients` derivata dal `named.conf.options` finale.
- `rollback/README.md` — checkpoint e rollback descritti nel capitolo.

## Verifiche principali

WireGuard:

```bash
systemctl is-enabled wg-quick@wg0
systemctl is-active wg-quick@wg0
ip -br addr show wg0
ip route show 10.99.10.0/24
sudo wg show
sudo nft -c -f /etc/nftables.conf
```

OpenVPN:

```bash
systemctl is-enabled openvpn-server@ch12
systemctl is-active openvpn-server@ch12
ip -br addr show tun0
ip route show 10.99.20.0/24
sudo ss -lunp | grep ':1194\b'
sudo journalctl -u openvpn-server@ch12 -n 30 --no-pager
```

Non esiste un file `verify-vpn.sh` del laboratorio: le verifiche sono i comandi riportati nel capitolo e qui sopra.

## Materiale da non versionare

- chiavi private WireGuard;
- `ca.key`;
- chiavi private OpenVPN;
- `tls-crypt.key`;
- profili `.ovpn` reali completi;
- credenziali o altri secret.

Gli esempi pubblicati nel repository devono rimanere privi di segreti.
