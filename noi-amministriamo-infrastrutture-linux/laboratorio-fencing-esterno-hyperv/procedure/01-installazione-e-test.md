# Installazione e test R1 — agente Hyper-V sperimentale

**Ambiente verificato:** Ubuntu 24.04.5, Pacemaker 2.1.6, PCS 0.11.7, libreria `fencing` 4.12.1, Windows Hyper-V con OpenSSH/PowerShell. Tutte le prove distruttive hanno riguardato la sola VM `web01`.

## Prerequisiti

- Account Windows già autorizzato a usare `Get-VM`, `Start-VM`, `Stop-VM`; l'esempio del laboratorio usa `Utente`.
- Autenticazione SSH **non interattiva** dai due nodi; chiavi private separate, permessi stretti, host key Windows verificata.
- Chiavi pubbliche degli account amministrativi Windows nel file standard `C:\ProgramData\ssh\administrators_authorized_keys` con ACL adeguate.
- Pacchetti Ubuntu già installati: `pacemaker`, `corosync`, `pcs`, `fence-agents-base`.
- VM `web01` sacrificabile durante i test, **mai** fermare servizi produttivi; assicurarsi che non stia servendo Nextcloud al momento del test.

## Installazione sul singolo nodo (ripetere sul secondo)

Con il sorgente presente in `~/fence_hyperv_lab_R1.py`:

```bash
sudo install -o root -g root -m 755 ~/fence_hyperv_lab_R1.py /usr/sbin/fence_hyperv_lab
sudo pcs stonith describe fence_hyperv_lab
```

Il file usa la libreria di sistema in `/usr/share/fence`. Non copiare `fencing.py` nel progetto.

## Verifica autonoma

```bash
sudo /usr/sbin/fence_hyperv_lab --action=monitor \
  --ip=10.77.0.254 --username=Utente --ssh --plug=web01 \
  --identity-file=/home/labadmin/.ssh/id_ed25519_ch23_fencing
echo "EXIT CODE: $?"
```

Atteso: exit 0. `status` restituisce **2** quando la VM è `Off` (convenzione della libreria). `on` e `off` sono state validate con exit 0, seguite da una nuova interrogazione dello stato. Non eseguirle contro VM che ospitano servizi richiesti.

## Registrazione in PCS — limitata alla VM di prova

```bash
sudo pcs stonith create ch23-fence-hyperv-lab \
  fence_hyperv_lab \
  ip=10.77.0.254 username=Utente ssh=1 \
  identity_file=/home/labadmin/.ssh/id_ed25519_ch23_fencing \
  plug=web01 pcmk_host_list=web01 pcmk_host_check=static-list \
  --disabled
```

La risorsa è stata in seguito abilitata e risultava Started su `dhcp-client01`:

```bash
sudo pcs stonith enable ch23-fence-hyperv-lab --wait=30
sudo stonith_admin --list=web01
```

Il secondo comando ha restituito `ch23-fence-hyperv-lab` e `1 fence device found`.

## Test di fencing manuale via Pacemaker (realmente eseguito)

Dopo aver acceso volontariamente `web01`, si è eseguito:

```bash
sudo stonith_admin --fence=web01 --timeout=60
echo "EXIT CODE: $?"
```

Risultato: exit 0. Una nuova interrogazione indipendente di Hyper-V ha mostrato `web01 Off`. La forma `stonith_admin --fence=web01 --off` **non** è supportata: aveva restituito errore `Unknown option --off` (exit 64).

## Limitazioni

- L'agente R1 ha allowlist `web01`; non può alimentare nodi del cluster.
- `stonith-enabled=false` **non è stato cambiato**; il successo del comando manuale non abilita il fencing automatico.
- Il codice non gestisce scenari di partizione, deadlock, guasto Hyper-V, credenziali revocate, gestione avanzata di timeout o riavvio di nodi Pacemaker.
- Il percorso della chiave punta all'utente `labadmin`, ma PCS esegue l'agente nel contesto di servizio/root: verificare sempre le autorizzazioni nel sistema reale.
