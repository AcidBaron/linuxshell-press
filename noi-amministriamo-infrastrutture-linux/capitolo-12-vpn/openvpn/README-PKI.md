# OpenVPN – PKI, client multipli e revoca

Comandi derivati dal laboratorio realmente validato del Capitolo 12. Le chiavi private e i profili reali non devono essere pubblicati.

## Installazione

```bash
sudo apt update
sudo apt install -y openvpn easy-rsa
```

## Preparare Easy-RSA e la CA

```bash
sudo install -d -m 700 /etc/openvpn/easy-rsa
sudo cp -a /usr/share/easy-rsa/. /etc/openvpn/easy-rsa/
cd /etc/openvpn/easy-rsa

sudo ./easyrsa init-pki
sudo ./easyrsa \
    --batch \
    --req-cn="Linuxshell Press OpenVPN Lab CA" \
    build-ca
```

## Certificato server

```bash
sudo ./easyrsa \
    --batch \
    --req-cn="fw01-openvpn" \
    gen-req fw01-openvpn nopass

sudo ./easyrsa sign-req server fw01-openvpn
```

## Primo client

```bash
sudo ./easyrsa \
    --batch \
    --req-cn="windows-client01" \
    gen-req windows-client01 nopass

sudo ./easyrsa sign-req client windows-client01
sudo ./easyrsa gen-crl
```

## File runtime

```bash
sudo install -d -o root -g root -m 755 /etc/openvpn/server
sudo install -o root -g root -m 644 pki/ca.crt /etc/openvpn/server/ca.crt
sudo install -o root -g root -m 644 pki/issued/fw01-openvpn.crt /etc/openvpn/server/fw01-openvpn.crt
sudo install -o root -g root -m 600 pki/private/fw01-openvpn.key /etc/openvpn/server/fw01-openvpn.key
sudo install -o root -g root -m 644 pki/crl.pem /etc/openvpn/server/crl.pem
sudo openvpn --genkey tls-crypt /etc/openvpn/server/tls-crypt.key
sudo chmod 600 /etc/openvpn/server/tls-crypt.key
```

## Secondo client

```bash
cd /etc/openvpn/easy-rsa
sudo ./easyrsa \
    --batch \
    --req-cn="windows-client02" \
    gen-req windows-client02 nopass
sudo ./easyrsa sign-req client windows-client02
```

Nel laboratorio `windows-client02` ha ricevuto `10.99.20.3`, mentre `windows-client01` ha mantenuto `10.99.20.2`.

## Revocare windows-client02

```bash
cd /etc/openvpn/easy-rsa
sudo ./easyrsa revoke windows-client02
sudo ./easyrsa gen-crl
sudo install -o root -g root -m 644 pki/crl.pem /etc/openvpn/server/crl.pem
```

Verifica:

```bash
sudo grep '^R' /etc/openvpn/easy-rsa/pki/index.txt
sudo openssl crl -in /etc/openvpn/server/crl.pem -noout -text |
    grep -A3 'Revoked Certificates'
```

Una nuova connessione di `windows-client02` deve essere rifiutata; `windows-client01` deve continuare a funzionare.

## Avvio e verifica server

```bash
sudo systemctl enable --now openvpn-server@ch12
systemctl is-enabled openvpn-server@ch12
systemctl is-active openvpn-server@ch12
ip -br addr show tun0
ip route show 10.99.20.0/24
sudo ss -lunp | grep ':1194\b'
sudo journalctl -u openvpn-server@ch12 -n 30 --no-pager
```

Il log deve contenere `Initialization Sequence Completed`.