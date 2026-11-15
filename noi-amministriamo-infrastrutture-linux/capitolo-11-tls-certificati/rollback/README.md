# Rollback – Capitolo 11

Il Capitolo 11 estende lo stato validato del Capitolo 10 aggiungendo TLS e trust della Lab CA.

## Checkpoint consigliati

- `CH11-RP01-PRE-TLS`
- `CH11-WEB01-PRE-TLS`
- `CH11-CLIENT-PRE-CA-TRUST`
- `CH11-RP01-TLS-FINAL-VALIDATED`
- `CH11-WEB01-TLS-FINAL-VALIDATED`
- `CH11-CLIENT-CA-TRUST-VALIDATED`

## HAProxy

Backup creato prima dell'estensione TLS:

`/etc/haproxy/haproxy.cfg.pre-ch11-tls`

Ripristinare il file, validare con `haproxy -c -f /etc/haproxy/haproxy.cfg` e riavviare HAProxy.

## Nginx

Ripristinare i server block del Capitolo 10 oppure rimuovere le sezioni `listen 443 ssl`; validare sempre con `nginx -t` prima del reload.

## Trust store del client

Per rimuovere la Lab CA:

```bash
sudo rm -f /usr/local/share/ca-certificates/linuxshell-lab-ca.crt
sudo update-ca-certificates --fresh
```

## Materiale crittografico

Le chiavi private non vengono versionate. In caso di rollback completo usare i checkpoint Hyper-V o eliminare il materiale generato sotto `/etc/ssl/linuxshell-lab-ca`, `/etc/nginx/tls` e `/etc/haproxy/certs` solo dopo essersi assicurati che non sia più necessario.
