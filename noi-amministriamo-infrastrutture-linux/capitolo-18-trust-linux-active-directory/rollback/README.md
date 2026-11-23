# Capitolo 18 — rollback operativo

Il punto di ritorno protetto prima del trust è:

```text
CH18-PRE-AD-TRUST
```

Al termine del laboratorio viene sostituito dai checkpoint:

```text
CH18-AD-TRUST-COMPLETE
```

## Ripristino rapido Hyper-V

Se il trust deve essere annullato integralmente durante il laboratorio, ripristinare i checkpoint pre-trust di `ipa01` e `dc01`.

## Rimozione logica delle modifiche

Prima di usare questi comandi in una infrastruttura diversa verificare dipendenze e policy locali.

Su IdM, il trust può essere rimosso con:

```bash
kinit admin
ipa trust-del ad.lab.test
```

La forward zone IdM verso AD può essere rimossa con:

```bash
ipa dnsforwardzone-del ad.lab.test
```

Il file named precedente alla modifica DNSSEC è stato salvato in:

```text
/etc/named/ipa-options-ext.conf.pre-ch18-ad-trust
```

Per ripristinarlo:

```bash
sudo cp -a \
    /etc/named/ipa-options-ext.conf.pre-ch18-ad-trust \
    /etc/named/ipa-options-ext.conf

sudo named-checkconf
sudo systemctl restart named
```

Su `dc01`, rimuovere la conditional forwarder zone:

```powershell
Remove-DnsServerZone `
    -Name "idm.lab.test" `
    -Force
```

I gruppi creati dal capitolo sono:

```text
ad_users_external
ad_users
```

Rimuoverli solo se non sono già usati da altre policy IdM.
