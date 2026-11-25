# VRRP unicast, health check e prima elezione

**Nodi:** rp01=10.77.0.50 (priorità 150), proxy01=10.77.0.40 (priorità 100), VIP 10.77.0.90/24 su eth0, VRID 22.

## Installazione e prerequisiti mirati

**Su entrambe le VM, Bash:**

```bash
sudo apt install -y keepalived
sudo systemctl disable --now keepalived
ip -4 -br addr show
```

**Su linux-client01, Bash** (indizio di indirizzo VIP non occupato: nessuna risposta; neighbor INCOMPLETE):

```bash
ping -c 2 -W 1 10.77.0.90
ip neigh show 10.77.0.90
```

La mancata risposta ARP/ping non sostituisce l'inventario degli indirizzi assegnati.

**Su rp01, Bash:** VRRP è IP protocol 112, non TCP/UDP.

```bash
sudo ufw allow in on eth0 \
    proto vrrp \
    from 10.77.0.40 \
    to 10.77.0.50 \
    comment 'CH22 VRRP proxy01'
```

**Su proxy01, Bash:**

```bash
sudo ufw allow in on eth0 \
    proto vrrp \
    from 10.77.0.50 \
    to 10.77.0.40 \
    comment 'CH22 VRRP rp01'
```

## Installare i file Keepalived

**Su ciascun nodo**, creare la directory e salvare un eventuale file precedente:

```bash
sudo install -d -m 0755 /etc/keepalived
if sudo test -f /etc/keepalived/keepalived.conf; then
    sudo cp -a \
        /etc/keepalived/keepalived.conf \
        /etc/keepalived/keepalived.conf.pre-ch22
fi
```

Quindi creare \`/etc/keepalived/keepalived.conf\` con \`sudo tee ... <<'EOF'\` e l'intero contenuto del rispettivo file nel repository:

- [rp01.keepalived.conf](../config/rp01.keepalived.conf)
- [proxy01.keepalived.conf](../config/proxy01.keepalived.conf)

I file sono completi e riportano \`vrrp_version 3\`, \`state BACKUP\`, \`unicast_src_ip\`, \`unicast_peer\`, \`track_script\`, \`virtual_router_id 22\` e VIP.

Il controllo Nginx è \`/usr/bin/systemctl is-active --quiet nginx\`; \`interval 2\`, \`fall 2\`, \`rise 2\` e \`weight 0\` causano FAULT del nodo con Nginx fermo dopo due fallimenti consecutivi.

**Su entrambi, prima dell'avvio:**

```bash
sudo keepalived -t \
    -f /etc/keepalived/keepalived.conf
```

Risultato osservato: il controllo è terminato senza errori su entrambi.

## Sequenza di avvio

**proxy01, Bash:**

```bash
sudo systemctl enable --now keepalived
ip -4 -br addr show dev eth0
```

Si è osservato proxy01 con 10.77.0.40/24 + 10.77.0.90/24.

**rp01, Bash:**

```bash
sudo systemctl enable --now keepalived
ip -4 -br addr show dev eth0
```

Si è osservato rp01 con 10.77.0.50/24 + 10.77.0.90/24. Su proxy01, dopo qualche secondo, \`ip -4 -br addr show dev eth0\` mostrava soltanto 10.77.0.40/24.

**linux-client01, Bash:**

```bash
curl -I \
    --resolve nextcloud.lab.test:443:10.77.0.90 \
    https://nextcloud.lab.test/
```

Risultato validato: HTTP 302 verso login Nextcloud. Se la VIP è presente contemporaneamente su entrambe le VM, arrestare Keepalived sullo standby e diagnosticare VRRP prima delle prove applicative.
