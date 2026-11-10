# Capitolo 9 – Proxy forward con Squid

Materiale operativo associato al Capitolo 9 di **Noi Amministriamo Infrastrutture Linux**.

## Stato finale validato

- Server: `proxy01`, IPv4 `10.77.0.40/24`.
- Gateway: `10.77.0.1`; DNS interno: `10.77.0.10`; dominio: `lab.test`.
- Squid: `6.14-0ubuntu0.24.04.5` su Ubuntu 24.04.
- Proxy esplicito su TCP/3128.
- HTTP consentito su TCP/80.
- HTTPS tramite metodo CONNECT verso TCP/443, senza SSL bump.
- ACL sorgente limitata a `10.77.0.0/24`.
- Blocklist dimostrativa: `.example.net`.
- Autenticazione Basic NCSA con utente di laboratorio `proxyuser`.
- Password didattica usata nel laboratorio: `123` (LAB ONLY).
- Cache RAM: 128 MB.
- Cache persistente UFS: 1 GB in `/var/spool/squid`.
- UFW: default deny incoming; TCP/22 e TCP/3128 ammessi solo da `10.77.0.0/24`.
- DNS: `proxy01.lab.test A 10.77.0.40` e PTR corrispondente.
- Windows NRPT: aggiunta la reverse zone `.0.77.10.in-addr.arpa` verso `10.77.0.10`.
- Reboot completo e persistenza di servizio, firewall, autenticazione, blocklist e cache: PASS.

## Checkpoint Hyper-V

- `CH9-PROXY01-PRE-SQUID`
- `CH9-SQUID-BASIC-VALIDATED`
- `CH9-SQUID-UFW-VALIDATED`
- `CH9-SQUID-DISK-CACHE-VALIDATED`
- `CH9-SQUID-DOMAIN-ACL-VALIDATED`
- `CH9-SQUID-AUTH-VALIDATED`
- `CH9-SQUID-FINAL-VALIDATED`

## File

- `config/squid.conf` — configurazione finale validata.
- `config/blocked-domains.txt` — blocklist dimostrativa.
- `dns/proxy01.records` — record A/PTR aggiunti a BIND.
- `linux/configure-ufw.sh` — policy firewall del server.
- `linux/create-lab-user.sh` — creazione del file NCSA; usa una password inserita interattivamente.
- `linux/verify-final-state.sh` — verifica finale del server e aspettative end-to-end.
- `windows/add-lab-reverse-nrpt.ps1` — regola NRPT reverse emersa durante il laboratorio.
- `rollback/README.md` — punti di rollback e file di backup realmente creati.

## Failure case documentati

1. **infra01 spenta**: `proxy01` raggiungeva gateway e Internet ma non il DNS interno; il problema era disponibilità/L2 del server, non Squid.
2. **Configurazione Ubuntu di default**: Squid ascoltava su 3128 ma il client riceveva `TCP_DENIED/403` perché terminava con `http_access deny all`.
3. **ACL localhost duplicata**: la ridefinizione manuale della ACL predefinita produceva warning; la definizione duplicata è stata rimossa.
4. **Inizializzazione cache**: `squid -z` manuale seguito immediatamente da `systemctl start squid` ha prodotto una race. La procedura corretta usa systemd, che esegue già `squid --foreground -z` in ExecStartPre.
5. **Split DNS Windows**: la NRPT `.lab.test` non copriva automaticamente la zona PTR. È stata aggiunta una regola separata per `.0.77.10.in-addr.arpa`.
6. **Autenticazione vs autorizzazione**: l'ordine finale forza prima l'autenticazione e poi applica la blocklist, così il log mostra `proxyuser` anche sui `403` di policy.

## Risultati finali

- senza credenziali -> `407 Proxy Authentication Required`;
- `proxyuser` + destinazione consentita HTTP -> `TCP_HIT/200` o `TCP_MISS/200`;
- `proxyuser` + HTTPS consentito -> `TCP_TUNNEL/200`;
- `proxyuser` + `example.net` -> `TCP_DENIED/403`, sia HTTP sia CONNECT HTTPS;
- dopo restart/reboot, la cache UFS ha ricaricato l'oggetto da disco e ha restituito `TCP_HIT/200`.

La password `123` è intenzionalmente debole e serve esclusivamente al laboratorio. In ambienti reali deve essere sostituita con credenziali robuste o con autenticazione centralizzata.
