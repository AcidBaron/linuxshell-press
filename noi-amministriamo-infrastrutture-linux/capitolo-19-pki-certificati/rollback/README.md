# Capitolo 19 — rollback operativo

## Hyper-V

Punto di ritorno temporaneo: `CH19-PRE-PKI-LIFECYCLE`.

Stato finale validato: `CH19-PKI-LIFECYCLE-COMPLETE`.

## Nginx

```bash
sudo cp -a     /etc/nginx/tls/sito1.lab.test.crt.pre-ch19     /etc/nginx/tls/sito1.lab.test.crt

sudo cp -a     /etc/nginx/tls/sito1.lab.test.key.pre-ch19     /etc/nginx/tls/sito1.lab.test.key

sudo nginx -t
sudo systemctl reload nginx
```

## HAProxy

```bash
sudo cp -a     /etc/haproxy/certs/sito1.lab.test.pem.pre-ch19     /etc/haproxy/certs/sito1.lab.test.pem

sudo haproxy -c -f /etc/haproxy/haproxy.cfg
sudo systemctl reload haproxy
```

Le chiavi private non sono versionate. Per un rollback completo del lifecycle durante lo sviluppo usare il checkpoint Hyper-V invece di cancellare selettivamente database, seriali e chiavi della Issuing CA.
