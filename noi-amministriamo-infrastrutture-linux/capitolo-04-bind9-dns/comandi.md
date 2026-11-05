# Capitolo 4 – DNS con BIND9 — comandi e configurazioni
> Estratto operativo dal master `cap4_bind9.docx`. I blocchi sono riportati nell'ordine del capitolo.

## 4.1 Obiettivo, ruoli e spazio dei nomi

```bash
linux-client01
      |
      | DNS
      v
infra01 / BIND9  10.77.0.10
      |\
      | \__ lab.test -> risposta autorevole locale
      |
      \____ Internet -> forwarder 1.1.1.1 / 8.8.8.8
```

## 4.2 Baseline pre-BIND: rete, resolver e porta 53

```bash
hostnamectl --static
grep '^PRETTY_NAME=' /etc/os-release
ip -br -4 addr
ip -4 route
resolvectl status
sudo ss -lntup | grep -E '(:53[[:space:]]|:53$)'
```

## 4.3 Installare BIND9 e gli strumenti di diagnosi

```bash
sudo apt update
sudo apt install -y \
  bind9 \
  bind9-utils \
  bind9-dnsutils
```

```bash
dpkg-query -W -f='${binary:Package}\t${Version}\t${Status}\n' \
  bind9 bind9-utils bind9-dnsutils
named -v
systemctl is-enabled named.service
systemctl is-active named.service
systemctl status named.service --no-pager -l
```

## 4.4 Un failure reale: SERVFAIL nonostante il servizio attivo

```bash
dig @10.77.0.10 ubuntu.com A \
  +time=3 +tries=1 \
  +noall +comments +answer
```

## 4.5 Limitare BIND alla LAB-LAN e usare forwarder espliciti

```conf
acl "lab_clients" {
    127.0.0.1;
    10.77.0.0/24;
};

options {
    directory "/var/cache/bind";

    listen-on {
        127.0.0.1;
        10.77.0.10;
    };

    listen-on-v6 { none; };

    recursion yes;
    allow-query { lab_clients; };
    allow-recursion { lab_clients; };
    allow-query-cache { lab_clients; };

    forwarders {
        1.1.1.1;
        8.8.8.8;
    };
    forward only;

    dnssec-validation auto;
    minimal-responses yes;
};
```

## 4.6 DNSSEC: diagnosi della catena di fiducia e workaround del laboratorio

```bash
dig @1.1.1.1 cloudflare.com A +dnssec \
  +time=3 +tries=1 +noall +comments +answer

dig @10.77.0.10 cloudflare.com A +dnssec +cdflag \
  +time=3 +tries=1 +noall +comments +answer

sudo journalctl -u named --since "15 minutes ago" --no-pager | tail -n 80
```

```bash
sudo cp -a /etc/bind/named.conf.options \
  /etc/bind/named.conf.options.pre-dnssec-workaround

sudo sed -i \
  's/dnssec-validation auto;/dnssec-validation no;/' \
  /etc/bind/named.conf.options

sudo named-checkconf
sudo systemctl reload named
```

## 4.7 Creare la zona diretta e la zona inversa

```conf
zone "lab.test" {
    type primary;
    file "/etc/bind/db.lab.test";
};

zone "0.77.10.in-addr.arpa" {
    type primary;
    file "/etc/bind/db.10.77.0";
};
```

```bash
$TTL 3600
@   IN  SOA infra01.lab.test. hostmaster.lab.test. (
        2026101501 ; serial
        3600       ; refresh
        900        ; retry
        604800     ; expire
        300        ; negative cache TTL
)

    IN  NS  infra01.lab.test.

fw01            IN  A   10.77.0.1
infra01         IN  A   10.77.0.10
linux-client01  IN  A   10.77.0.101
```

```bash
$TTL 3600
@   IN  SOA infra01.lab.test. hostmaster.lab.test. (
        2026101501
        3600
        900
        604800
        300
)

    IN  NS  infra01.lab.test.

1       IN  PTR fw01.lab.test.
10      IN  PTR infra01.lab.test.
101     IN  PTR linux-client01.lab.test.
```

```bash
sudo chown root:bind /etc/bind/db.lab.test /etc/bind/db.10.77.0
sudo chmod 0644 /etc/bind/db.lab.test /etc/bind/db.10.77.0
```

## 4.8 Validare configurazione e zone prima del reload

```bash
sudo named-checkconf

sudo named-checkzone lab.test /etc/bind/db.lab.test

sudo named-checkzone \
  0.77.10.in-addr.arpa \
  /etc/bind/db.10.77.0

sudo named-checkconf -z
```

```bash
sudo systemctl reload named
sudo journalctl -u named --since "2 minutes ago" --no-pager | tail -n 40
```

## 4.9 Verificare risposte autorevoli forward e reverse

```bash
dig @10.77.0.10 infra01.lab.test A \
  +norecurse +noall +comments +answer

dig @10.77.0.10 fw01.lab.test A \
  +norecurse +noall +comments +answer

dig @10.77.0.10 linux-client01.lab.test A \
  +norecurse +noall +comments +answer
```

```bash
dig @10.77.0.10 -x 10.77.0.1 \
  +norecurse +noall +comments +answer

dig @10.77.0.10 -x 10.77.0.10 \
  +norecurse +noall +comments +answer

dig @10.77.0.10 -x 10.77.0.101 \
  +norecurse +noall +comments +answer
```

## 4.10 Configurare linux-client01 per usare infra01

```bash
sudo cp -a \
  /etc/netplan/50-cloud-init.yaml \
  /etc/netplan/50-cloud-init.yaml.pre-infra01-dns
```

```bash
network:
  version: 2
  ethernets:
    eth0:
      addresses:
        - 10.77.0.101/24
      nameservers:
        addresses:
          - 10.77.0.10
        search:
          - lab.test
      routes:
        - to: default
          via: 10.77.0.1
```

```bash
sudo netplan generate
sudo netplan apply
```

## 4.11 Test end-to-end: NSS, nome corto, reverse e Internet

```bash
dig infra01.lab.test A +noall +comments +answer
dig -x 10.77.0.10 +noall +comments +answer

getent ahostsv4 infra01.lab.test
getent ahostsv4 fw01.lab.test
getent ahostsv4 linux-client01.lab.test

getent ahostsv4 infra01
getent ahostsv4 fw01
```

```bash
getent ahostsv4 ubuntu.com | head

curl -4 -sS \
  -o /dev/null \
  -w 'HTTP status: %{http_code}\n' \
  https://ubuntu.com

getent hosts 10.77.0.10
getent hosts 10.77.0.1
getent hosts 10.77.0.101
```

## 4.12 NXDOMAIN autorevole e negative caching

```bash
dig @10.77.0.10 \
  host-inesistente.lab.test A \
  +norecurse \
  +noall +comments +authority
```

## 4.13 Modificare una zona: seriale, CNAME e reload selettivo

```bash
sudo cp -a \
  /etc/bind/db.lab.test \
  /etc/bind/db.lab.test.pre-dns-alias

sudo sed -i \
  's/2026101501/2026101502/' \
  /etc/bind/db.lab.test

echo 'dns     IN  CNAME  infra01.lab.test.' | \
  sudo tee -a /etc/bind/db.lab.test
```

```bash
sudo sed -i \
  's/2026101502/2026101503/' \
  /etc/bind/db.lab.test

sudo named-checkzone lab.test /etc/bind/db.lab.test
sudo rndc reload lab.test
sudo rndc zonestatus lab.test
```

```bash
dig @10.77.0.10 lab.test SOA \
  +norecurse +noall +answer

dig dns.lab.test CNAME +noall +comments +answer
dig dns.lab.test A +noall +comments +answer
getent ahostsv4 dns.lab.test
```

## 4.16 Verifica finale e checkpoint

```bash
sudo named-checkconf -z

systemctl is-enabled named
systemctl is-active named

sudo ss -lntup | \
  grep -E '10\.77\.0\.10:53|127\.0\.0\.1:53'

dig @10.77.0.10 lab.test SOA \
  +norecurse +noall +answer

dig @10.77.0.10 ubuntu.com A \
  +noall +comments +answer
```

```powershell
Checkpoint-VM `
  -Name "infra01" `
  -SnapshotName "CH4-DNS-BIND9-VALIDATED"

Checkpoint-VM `
  -Name "linux-client01" `
  -SnapshotName "CH4-DNS-CLIENT-VALIDATED"
```
