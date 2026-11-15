# Capitolo 12 – VPN con WireGuard e OpenVPN

Materiale operativo associato al Capitolo 12 di **Noi Amministriamo Infrastrutture Linux** — Linuxshell Press.

Il libro resta la fonte didattica autorevole. Questo albero contiene configurazioni, comandi e procedure derivati dal laboratorio realmente validato. **Nessuna chiave privata, profilo reale o secret del laboratorio è pubblicato.**

## Topologia validata

- Host Windows / Hyper-V: `VPN-WAN = 10.250.0.1/24`, WinNAT `VPN-WAN-NAT`.
- `fw01 eth0 = 10.250.0.2/24`.
- WireGuard: `wg0 = 10.99.10.1/24`, UDP/51820; client01 `10.99.10.2`.
- OpenVPN: `tun0 = 10.99.20.1/24`, UDP/1194; client01 `10.99.20.2`, client02 `10.99.20.3` prima della revoca.
- `infra01 = 10.77.0.10`, DNS BIND.
- Checkpoint finale: `CH12-VPN-FINAL-VALIDATED`.

## Tre scenari da non confondere

### 1. Laboratorio realmente validato

Il PC Windows usato per simulare il client remoto è anche collegato direttamente alla LAB-LAN. Per evitare che il tunnel interferisca con le normali sessioni amministrative, il laboratorio instrada nel tunnel soltanto destinazioni precise.

```ini
AllowedIPs = 10.99.10.0/24, 10.77.0.10/32
```

OpenVPN usa analogamente una route `/32` verso `10.77.0.10`.

### 2. Client realmente remoto / smart working

Un PC esterno alla sede non possiede una connessione diretta alla LAB-LAN. In questo caso è normale instradare nel tunnel l'intera rete interna necessaria.

```ini
AllowedIPs = 10.99.10.0/24, 10.77.0.0/24
```

Per OpenVPN:

```text
push "route 10.77.0.0 255.255.255.0"
```

Le ACL applicative e i firewall dei server interni devono comunque autorizzare le subnet VPN.

### 3. Server VPN dedicato

Se WireGuard/OpenVPN terminano su una VM dedicata `vpn01` invece che su `fw01`, la LAN deve conoscere il percorso di ritorno verso le reti VPN. Routing puro conserva gli IP `10.99.x.x`; il NAT semplifica il return path ma nasconde il client.

Con `vpn01 = 10.77.0.60`:

```bash
sudo ip route add 10.99.10.0/24 via 10.77.0.60
sudo ip route add 10.99.20.0/24 via 10.77.0.60
```

## WireGuard: installazione e chiavi server

```bash
sudo apt update
sudo apt install -y wireguard
sudo install -d -o root -g root -m 700 /etc/wireguard
sudo sh -c 'umask 077; wg genkey > /etc/wireguard/fw01-private.key; wg pubkey < /etc/wireguard/fw01-private.key > /etc/wireguard/fw01-public.key'
sudo chmod 600 /etc/wireguard/fw01-private.key
sudo chmod 600 /etc/wireguard/fw01-public.key
```

Dopo aver creato localmente `/etc/wireguard/wg0.conf`:

```bash
sudo chmod 600 /etc/wireguard/wg0.conf
sudo systemctl enable --now wg-quick@wg0
systemctl is-enabled wg-quick@wg0
systemctl is-active wg-quick@wg0
ip -br addr show wg0
ip route show 10.99.10.0/24
sudo wg show
```

## VPN-WAN su fw01

Il file `linux/90-ch12-vpn-wan.yaml` corrisponde alla configurazione Netplan finale. Prima della modifica:

```bash
sudo cp -a /etc/netplan /etc/netplan.pre-ch12-vpn-wan
sudo install -m 600 linux/90-ch12-vpn-wan.yaml /etc/netplan/90-ch12-vpn-wan.yaml
sudo netplan generate
```

Dal PC Hyper-V, dopo avere creato `VPN-WAN`:

```powershell
Connect-VMNetworkAdapter `
    -VMName "fw01" `
    -Name "WAN" `
    -SwitchName "VPN-WAN"
```

Poi su `fw01`:

```bash
sudo netplan apply
ip -4 -br addr show eth0
ip route show default
ping -c 3 10.250.0.1
ping -c 3 1.1.1.1
getent ahostsv4 archive.ubuntu.com | head
```

## Aggiungere client WireGuard

Ogni client deve avere una coppia di chiavi e un indirizzo tunnel distinti: client01 `.2`, client02 `.3`, client03 `.4` e così via.

```ini
[Peer]
# windows-client02
PublicKey = <WINDOWS_CLIENT02_PUBLIC_KEY>
AllowedIPs = 10.99.10.3/32

[Peer]
# windows-client03
PublicKey = <WINDOWS_CLIENT03_PUBLIC_KEY>
AllowedIPs = 10.99.10.4/32
```

Dopo avere aggiornato `/etc/wireguard/wg0.conf`:

```bash
sudo chmod 600 /etc/wireguard/wg0.conf
sudo systemctl restart wg-quick@wg0
sudo wg show
ip route show 10.99.10.0/24
```

## Revocare un client WireGuard

WireGuard non usa CRL. Per revocare un client si elimina dal server il peer associato alla sua chiave pubblica.

```bash
sudo cp -a /etc/wireguard/wg0.conf /etc/wireguard/wg0.conf.pre-revoke
sudo wg set wg0 peer '<CLIENT_PUBLIC_KEY>' remove
sudo wg show
```

La sezione `[Peer]` deve essere rimossa anche da `/etc/wireguard/wg0.conf`, altrimenti ricomparirà al riavvio del servizio. Una chiave privata persa o compromessa non va riutilizzata.

## Revoca OpenVPN

OpenVPN usa certificati X.509 e CRL. `windows-client02` è stato validato prima della revoca con `10.99.20.3`; dopo la revoca la sua nuova connessione è stata rifiutata mentre `windows-client01` ha continuato a funzionare. Vedere `openvpn/README-PKI.md`.

## Verificare il percorso reale

Client Windows:

```powershell
Find-NetRoute -RemoteIPAddress 10.77.0.10 |
    Select-Object InterfaceAlias,DestinationPrefix,NextHop,RouteMetric
```

WireGuard:

```powershell
& "$env:ProgramFiles\WireGuard\wg.exe" show
```

`fw01`:

```bash
sudo nft list chain inet filter forward | grep -E 'wg0|tun0'
```

## File

- `hyper-v/create-vpn-wan.ps1` — crea VPN-WAN e WinNAT.
- `linux/90-ch12-vpn-wan.yaml` — Netplan finale di `fw01 eth0`.
- `wireguard/` — configurazioni di esempio e nftables.
- `openvpn/` — configurazione server, profilo di esempio, PKI/CRL e nftables.
- `bind/vpn-acl.snippet` — subnet VPN per l'ACL `lab_clients`.
- `verify/verify-vpn.sh` — controllo locale dello stato finale.
- `rollback/README.md` — rollback della WAN di laboratorio.

## Non versionare

Chiavi private WireGuard, `ca.key`, chiavi private OpenVPN, `tls-crypt.key`, profili `.ovpn` reali, credenziali e altri secret.