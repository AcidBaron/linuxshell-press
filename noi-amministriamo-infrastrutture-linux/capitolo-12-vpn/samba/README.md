# Appendice Capitolo 12 – Samba attraverso WireGuard e OpenVPN

Questa appendice documenta il laboratorio realmente validato in cui un client Windows accede alla share Samba `\\files01.lab.test\dati` attraverso entrambe le VPN del Capitolo 12.

L'obiettivo non è soltanto mostrare che la VPN è connessa, ma provare l'intero percorso:

`Windows -> tunnel VPN -> fw01 -> LAB-LAN -> UFW su files01 -> Samba -> filesystem`.

## Stato di partenza

- `fw01` LAN: `10.77.0.1/24`.
- WireGuard: `10.99.10.0/24`; client Windows `10.99.10.2`.
- OpenVPN: `10.99.20.0/24`; `windows-client01 = 10.99.20.2`.
- `files01 = 10.77.0.20/24`.
- Samba 4.19.5.
- Share: `dati`, path `/srv/samba/dati`.
- Utente scrittura: `smbuser`, gruppo `smbusers`.
- Il PC Windows del laboratorio è anche collegato direttamente alla LAB-LAN; per questo usiamo route host `/32` per dimostrare senza ambiguità quale percorso viene usato.

La share validata su `files01` è:

```ini
[dati]
    create mask = 0660
    directory mask = 02770
    force group = smbusers
    path = /srv/samba/dati
    valid users = @smbusers
    write list = smbuser
```

## 1. WireGuard: forzare files01 nel tunnel

### PC Windows — WireGuard

Nel profilo già validato, aggiungere temporaneamente `10.77.0.20/32` agli `AllowedIPs` del peer server:

```ini
AllowedIPs = 10.99.10.0/24, 10.77.0.10/32, 10.77.0.20/32
```

Dopo la riattivazione del tunnel, PowerShell deve mostrare una route `/32` per `files01` sull'interfaccia WireGuard e il test TCP deve usare `10.99.10.2` come sorgente.

```powershell
Find-NetRoute -RemoteIPAddress 10.77.0.20 |
    Format-List InterfaceAlias,DestinationPrefix,NextHop,RouteMetric

Test-NetConnection -ComputerName 10.77.0.20 -Port 445 |
    Format-List ComputerName,RemoteAddress,RemotePort,InterfaceAlias,SourceAddress,TcpTestSucceeded
```

## 2. files01: autorizzare SMB dalla rete WireGuard

### Macchina: files01 — Shell: Bash/Linux

Prima della modifica è stato salvato un backup di `/etc/ufw/user.rules`. La regola validata è:

```bash
sudo ufw allow \
    from 10.99.10.0/24 \
    to 10.77.0.20 \
    port 445 \
    proto tcp \
    comment 'CH12 VPN-SAMBA WireGuard'
```

Verifica:

```bash
sudo ufw status numbered

sudo nft list chain ip filter ufw-user-input |
    grep -E '10\.99\.10\.0/24.*10\.77\.0\.20.*dport 445'
```

Nello stato finale raccolto dal laboratorio il contatore UFW per questa regola era maggiore di zero.

## 3. Verifica applicativa WireGuard

### PC Windows — PowerShell

Connettere la share con le credenziali Samba, senza inserire password nei comandi o nei file del repository:

```powershell
cmd /c 'net use Z: \\files01.lab.test\dati /user:smbuser * /persistent:no'
```

Nel laboratorio è stato creato e riletto `Z:\test-vpn-samba-wireguard.txt`.

### Macchina: files01 — Shell: Bash/Linux

La verifica server-side deve mostrare il client reale della VPN:

```bash
sudo smbstatus
sudo ss -tnp | grep ':445'
```

Esito validato:

```text
Username: smbuser
Machine: 10.99.10.2
Protocol: SMB3_11
```

La connessione TCP osservata sul server era `10.77.0.20:445 <- 10.99.10.2:<porta-client>`.

Al termine della prova WireGuard, nel client Windows è stato ripristinato il baseline:

```ini
AllowedIPs = 10.99.10.0/24, 10.77.0.10/32
```

## 4. OpenVPN: aggiungere files01 alle route push

### Macchina: fw01 — Shell: Bash/Linux

La configurazione server validata contiene entrambe le route host:

```text
push "route 10.77.0.10 255.255.255.255"
push "route 10.77.0.20 255.255.255.255"
```

Dopo ogni modifica:

```bash
sudo systemctl restart openvpn-server@ch12
sudo systemctl is-active openvvn-server@ch12
```

Dopo la riconnessione del client, il log deve contenere la seconda route nel `PUSH_REPLY`:

```bash
sudo journalctl \
    -u openvvn-server@ch12 \
    -n 40 \
    --no-pager |
grep 'PUSH_REPLY'
```

### PC Windows — PowerShell

```powershell
Find-NetRoute -RemoteIPAddress 10.77.0.20 |
    Format-List InterfaceAlias,DestinationPrefix,NextHop,RouteMetric
```

Esito validato:

```text
DestinationPrefix : 10.77.0.20/32
NextHop           : 10.99.20.1
```

Prima di autorizzare OpenVPN in UFW, il laboratorio ha verificato esplicitamente il blocco:

```powershell
Test-NetConnection -ComputerName 10.77.0.20 -Port 445
```

Esito pre-regola:

```text
SourceAddress    : 10.99.20.2
TcpTestSucceeded : False
```

Questo prova che il routing VPN funziona ma il firewall del server continua a proteggere Samba.

## 5. files01: autorizzare SMB dalla rete OpenVPN

### Macchina: files01 — Shell: Bash/Linux

La regola validata è:

```bash
sudo ufw allow \
    from 10.99.20.0/24 \
    to 10.77.0.20 \
    port 445 \
    proto tcp \
    comment 'CH12 VPN-SAMBA OpenVPN'
```

Verifica:

```bash
sudo ufw status numbered

sudo nft list chain ip filter ufw-user-input |
    grep -E '10\.99\.20\.0/24.*10\.77\.0\.20.*dport 445'
```

Nel file `user.rules` raccolto dal laboratorio le due regole effettive risultavano:

```text
-A ufw-user-input -p tcp -d 10.77.0.20 --dport 445 -s 10.99.10.0/24 -j ACCEPT
-A ufw-user-input -p tcp -d 10.77.0.20 --dport 445 -s 10.99.20.0/24 -j ACCEPT
```

Dopo la seconda regola, il test Windows ha restituito:

```text
SourceAddress    : 10.99.20.2
TcpTestSucceeded : True
```

## 6. Dimostrare il percorso sul firewall e sul server

### Macchina: fw01 — Shell: Bash/Linux

```bash
sudo nft list ruleset |
    grep -E 'tun0.*10\.99\.20\.0/24.*10\.77\.0\.0/24.*counter'
```

La raccolta finale mostrava traffico reale sulla regola:

```text
iifname "tun0" oifname "eth1" ip saddr 10.99.20.0/24 ip daddr 10.77.0.0/24 counter ... accept
```

### Macchina: files01 — Shell: Bash/Linux

```bash
sudo nft list chain ip filter ufw-user-input |
    grep -E '10\.99\.20\.0/24.*10\.77\.0\.20.*dport 445'
```

Anche il contatore di questa regola era maggiore di zero.

## 7. Verifica applicativa OpenVPN

### PC Windows — PowerShell

```powershell
cmd /c 'net use \\files01.lab.test\dati /delete /y' 2>$null
cmd /c 'net use Z: \\files01.lab.test\dati /user:smbuser * /persistent:no'
```

Il laboratorio ha creato e riletto:

```text
Z:\test-vpn-samba-openvpn.txt
```

### Macchina: files01 — Shell: Bash/Linux

```bash
sudo smbstatus
sudo ss -tnp | grep ':445'
sudo ls -l /srv/samba/dati/test-vpn-samba-openvpn.txt
```

Esito validato:

```text
Username: smbuser
Group: smbusers
Machine: 10.99.20.2
Protocol Version: SMB3_11
Signing: AES-128-GMAC
```

La connessione TCP osservata era:

```text
10.77.0.20:445 <- 10.99.20.2:61313
```

Il file risultava posseduto da `smbuser:smbusers` con permessi coerenti con la share.

## 8. Cosa dimostra il laboratorio

Il test separa tre controlli diversi:

1. **routing VPN** — il client deve realmente usare l'indirizzo VPN come sorgente;
2. **firewall del server** — avere una route non autorizza automaticamente TCP/445;
3. **autenticazione e permessi Samba** — dopo l'apertura UFW, Samba continua ad autenticare `smbuser` e ad applicare i propri permessi.

La VPN quindi non sostituisce le ACL applicative. Il percorso di rete e l'autorizzazione del servizio devono essere entrambi configurati e verificati.

## 9. Chiusura del laboratorio

Sul PC Windows:

```powershell
cmd /c 'net use Z: /delete /y'
```

Le configurazioni finali sono state fissate nel checkpoint Hyper-V:

```text
CH12-APPENDIX-SAMBA-VPN-VALIDATED
```

su `fw01` e `files01`.

I file di prova creati nella share possono essere mantenuti come evidenza fino alla chiusura editoriale e poi rimossi.

## Materiale non pubblicato

Il pacchetto di raccolta usato per l'audit conteneva anche il file generato `/etc/ufw/user.rules` e output runtime. Il file UFW completo non viene pubblicato qui perché include regole non pertinenti all'appendice e rappresenta uno stato generato dal sistema. Le due regole necessarie sono riportate sopra nella forma `ufw allow` realmente usata e validata.

Non pubblicare password Samba, chiavi private WireGuard, chiavi private OpenVPN, `tls-crypt.key` o profili `.ovpn` reali.
