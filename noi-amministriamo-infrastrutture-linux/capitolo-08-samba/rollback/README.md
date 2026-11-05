# Rollback – Capitolo 8

## Samba

Ripristinare il backup di `/etc/samba/smb.conf`, validarlo e riavviare `smbd`:

```bash
sudo cp -a /percorso/del/backup/smb.conf /etc/samba/smb.conf
sudo testparm -s
sudo systemctl restart smbd
```

## BIND

I backup creati prima dei record di `files01` sono:

- `/etc/bind/db.lab.test.pre-ch8-files01`
- `/etc/bind/db.10.77.0.pre-ch8-files01`

Ripristinare le zone, eseguire `named-checkzone` e quindi ricaricare BIND.

## UFW

Rimuovere soltanto le quattro aperture create dal capitolo, quindi disabilitare UFW se si vuole tornare allo stato pre-firewall:

```bash
sudo ufw delete allow from 10.77.0.0/24 to any port 22 proto tcp
sudo ufw delete allow from 10.77.0.0/24 to any port 445 proto tcp
sudo ufw delete allow from fd3a:7b4c:2d91:1::/64 to any port 22 proto tcp
sudo ufw delete allow from fd3a:7b4c:2d91:1::/64 to any port 445 proto tcp
sudo ufw --force disable
```

Non usare `ufw reset` per un rollback mirato.

## Hyper-V

Per tornare al checkpoint pre-reboot:

```powershell
Get-VMSnapshot -VMName "files01"
Restore-VMSnapshot `
    -VMName "files01" `
    -Name "CH8-SAMBA-PRE-REBOOT" `
    -Confirm:$false
```

Account e dati della share non devono essere eliminati per un semplice rollback di configurazione. La rimozione completa del servizio richiede prima il backup dei dati.
