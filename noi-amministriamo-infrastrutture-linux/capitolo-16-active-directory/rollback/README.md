# Capitolo 16 — rollback operativo

## dc01

Durante installazione e promozione, prima della validazione finale, il punto di ritorno è:

```text
CH16-PRE-ADDS-PROMOTION
```

Dopo la validazione completa viene creato `CH16-AD-LAB-COMPLETE` e il checkpoint temporaneo pre-promozione può essere eliminato.

## infra01 / BIND

Backup creati durante il laboratorio:

```text
/etc/bind/db.lab.test.pre-ch16-ad
/etc/bind/db.10.77.0.pre-ch16-ad
/etc/bind/db.lab.test.pre-ch16-ad-delegation
/etc/bind/named.conf.local.pre-ch16-ad
```

Dopo il ripristino dei file necessari:

```bash
sudo named-checkzone lab.test /etc/bind/db.lab.test
sudo named-checkconf
sudo rndc reconfig
sudo rndc reload lab.test
```

## linux-client01

Baseline precedente al join AD:

```text
CH15-PRE-FREEIPA-ENROLLMENT
```

Stato finale validato del Capitolo 16:

```text
CH16-AD-LAB-COMPLETE
```

Il checkpoint `CH15-FREEIPA-LAB-COMPLETE` resta disponibile per tornare al laboratorio FreeIPA del Capitolo 15.
