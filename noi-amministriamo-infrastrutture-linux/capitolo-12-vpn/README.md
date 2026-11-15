# Capitolo 12 – VPN con WireGuard e OpenVPN

Materiale operativo associato al Capitolo 12 di **Noi Amministriamo Infrastrutture Linux** — Linuxshell Press.

Il libro resta la fonte editoriale e didattica autorevole. I file finali pubblicati qui sono stati riallineati ai file realmente raccolti dal laboratorio; gli esempi che conterrebbero segreti usano placeholder espliciti.

## Topologia validata

- Host Windows / Hyper-V: `VPN-WAN = 10.250.0.1/24`, WinNAT `VPN-WAN-NAT`.
- `fw01 eth0 = 10.250.0.2/24`.
- WireGuard: `wg0 = 10.99.10.1/24`, UDP/51820; client01 `10.99.10.2`.
- OpenVPN: `tun0 = 10.99.20.1/24`, UDP/1194; client01 `10.99.20.2`, client02 `10.99.20.3` prima della revoca.
- `infra01 = 10.77.0.10`, DNS BIND.
- checkpoint finale: `CH12-VPN-FINAL-VALIDATED`.

## Tre scenari da non confondere

### 1. Laboratorio realmente validato

Il PC Windows usato come client remoto simulato è contemporaneamente collegato direttamente alla LAB-LAN. Per questo il laboratorio usa route molto specifiche verso `infra01`:

```ini
AllowedIPs = 10.99.10.0/24, 10.77.0.10/32
```

OpenVPN usa analogamente una route `/32`.

### 2. Client realmente remoto / smart working

Un client esterno alla sede non possiede la connessione diretta alla LAB-LAN. Normalmente instrada nella VPN l'intera rete interna che deve raggiungere:

```ini
AllowedIPs = 10.99.10.0/24, 10.77.0.0/24
```

Per OpenVPN l'equivalente è:

```text
push "route 10.77.0.0 255.255.255.0"
```

Firewall e ACL applicative devono comunque autorizzare le subnet VPN.

### 3. Server VPN dedicato

Se WireGuard/OpenVPN terminano su una VM dedicata `vpn01`, la rete interna deve conoscere il percorso di ritorno verso `10.99.10.0/24` e `10.99.20.0/24`. Il routing puro conserva gli IP reali dei client; il NAT semplifica il return path ma li nasconde dietro l'IP LAN del server VPN.

## Provenienza dei file

File finali realmente raccolti dal laboratorio:

- `linux/90-ch12-vpn-wan.yaml` — copia del Netplan finale di `fw01`.
- `nftables/nftables.conf` — copia completa del ruleset finale di `fw01`.
- `openvpn/ch12.conf` — copia del file server OpenVPN finale.
- `bind/named.conf.options` — copia del file BIND finale di `infra01`.

File derivati dai file reali con segreti sostituiti da placeholder:

- `wireguard/wg0.conf.example`
- `wireguard/windows-client.conf.example`
- `openvpn/windows-client.ovpn.example`

Estratti didattici ricavati dai file finali:

- `wireguard/nftables-wireguard.snippet`
- `openvpn/nftables-openvpn.snippet`
- `bind/vpn-acl.snippet`

Helper repository costruiti dai comandi già presenti nel capitolo:

- `hyper-v/create-vpn-wan.ps1`
- `openvpn/README-PKI.md`
- `verify/verify-vpn.sh`
- `rollback/README.md`

## Aggiungere client WireGuard

Ogni nuovo client usa una coppia di chiavi distinta e un indirizzo tunnel distinto:

- client01 → `10.99.10.2/32`
- client02 → `10.99.10.3/32`
- client03 → `10.99.10.4/32`

Sul server ogni peer ha una sezione dedicata:

```ini
[Peer]
PublicKey = <CLIENT02_PUBLIC_KEY>
AllowedIPs = 10.99.10.3/32
```

Dopo la modifica persistente di `/etc/wireguard/wg0.conf`:

```bash
sudo chmod 600 /etc/wireguard/wg0.conf
sudo systemctl restart wg-quick@wg0
sudo wg show
```

## Revocare un peer WireGuard

WireGuard non usa una CRL. Si rimuove la chiave pubblica autorizzata dal server e dalla configurazione persistente. Una chiave privata sospetta o compromessa non va riutilizzata.

## OpenVPN: multi-client e revoca

Il laboratorio ha validato un secondo certificato `windows-client02`, assegnato a `10.99.20.3`, e la sua successiva revoca tramite CRL senza interrompere `windows-client01`. Vedere `openvpn/README-PKI.md`.

## Laboratorio appendice: uso applicativo da smart working

L'uso applicativo della VPN sarà sviluppato come laboratorio appendice separato: accesso remoto, attraverso la VPN, alla share Samba già costruita nel Capitolo 8. L'appendice dimostrerà la differenza tra tunnel attivo, routing corretto e autorizzazione del servizio SMB, senza alterare la baseline validata di questo capitolo.

## Non versionare

Chiavi private WireGuard, `ca.key`, chiavi private OpenVPN, `tls-crypt.key`, profili `.ovpn` reali e credenziali.
