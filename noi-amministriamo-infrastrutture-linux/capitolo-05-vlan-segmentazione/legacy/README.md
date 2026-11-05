# VLAN legacy

Il capitolo mantiene questi esempi soltanto per riconoscere e migrare configurazioni storiche. Non sono la baseline Ubuntu 24.04 del laboratorio.

```text
auto eth2.10
iface eth2.10 inet static
    address 10.77.10.1/24
    vlan-raw-device eth2
```

Esempio storico con `vconfig`:

```bash
sudo vconfig add eth2 10
```
