# Capitolo 16 — Active Directory e integrazione Linux

Materiale operativo del Capitolo 16 di **Noi Amministriamo Infrastrutture Linux**.

Questa prima pubblicazione copre esclusivamente la preparazione del server Windows che diventerà il primo controller di dominio. Lo stato qui documentato è ancora **pre-AD DS**: `dc01` è una macchina standalone, il DNS parent non è stato modificato e il ruolo Active Directory Domain Services non è ancora installato.

Verifica del laboratorio per questa fase: **19 novembre 2026**.

## Perimetro validato

- VM: `dc01`
- Sistema: Windows Server 2025 Standard Evaluation
- Installazione: Server Core
- Hyper-V: Generation 2
- vCPU: 2
- RAM dinamica: 2–8 GB, startup 4 GB
- VHDX dinamico: 40 GB
- Switch: `LAB-LAN`
- IPv4: `10.77.0.80/24`
- Gateway: `10.77.0.1`
- DNS iniziale: `10.77.0.10` (`infra01`)
- Profilo rete Windows: `Private`
- Time zone: `W. Europe Standard Time`
- Accesso remoto: OpenSSH con PowerShell
- Autenticazione SSH validata: password + chiave Ed25519
- Futuro dominio AD: `ad.lab.test`
- Stato AD DS: **non ancora installato**

## Prerequisiti

Devono già esistere:

- host Windows 11 con Hyper-V operativo;
- switch interno Hyper-V `LAB-LAN`;
- `fw01` — `10.77.0.1/24`, gateway della LAB-LAN;
- `infra01` — `10.77.0.10/24`, DNS BIND autorevole per `lab.test`;
- rete IPv4 `10.77.0.0/24`;
- accesso a Internet durante installazione e attivazione dell'edizione Evaluation;
- ISO italiana di Windows Server 2025 Standard Evaluation conservata sull'host Hyper-V.

Il DNS iniziale di `dc01` punta a `infra01`. La relazione tra il DNS parent `lab.test` e il futuro DNS Active Directory di `ad.lab.test` verrà costruita soltanto dopo la promozione del controller di dominio.

## 1. Creare la VM dc01

**Macchina:** host Windows 11  
**Shell:** PowerShell amministrativa

Il blocco PowerShell validato è disponibile in:

`powershell/01-create-dc01-vm.ps1`

Prima dell'esecuzione verificare il valore di `$IsoPath`.

La VM viene creata con:

- Generation 2;
- 2 vCPU;
- RAM dinamica 2–8 GB, startup 4 GB;
- VHDX dinamico da 40 GB;
- scheda collegata a `LAB-LAN`;
- checkpoint automatici disabilitati;
- ISO collegata come primo dispositivo di boot.

## 2. Installare Windows Server 2025 Evaluation

Avviare la VM e aprire la console Hyper-V:

```powershell
Start-VM "dc01"
vmconnect.exe localhost dc01
```

Durante il setup scegliere **Windows Server 2025 Standard Evaluation** senza Desktop Experience, cioè Server Core.

### Troubleshooting — il boot dalla ISO non parte

Con una VM Generation 2 il prompt:

```text
Press any key to boot from CD or DVD
```

rimane disponibile per pochissimo tempo. Se non viene premuto un tasto, il firmware può mostrare `The boot loader failed`.

Nel laboratorio non era un problema della ISO né dell'ordine di boot: è bastato riavviare la VM e premere immediatamente un tasto quando compare il prompt.

### Nota operativa — conferma della password Administrator

Durante il primo setup di Server Core il tasto Invio non spostava correttamente il focus dal campo della prima password al campo di conferma.

Nel laboratorio è stato necessario usare i **tasti freccia** per portare il focus sul campo successivo e completare la conferma. È una particolarità dell'interfaccia di setup, non un errore della password.

La password di `Administrator` è una credenziale dedicata e **non viene pubblicata nel repository**.

## 3. Usare PowerShell Direct per la configurazione iniziale

Prima che SSH sia disponibile, dall'host Hyper-V:

```powershell
$cred = Get-Credential

Enter-PSSession `
    -VMName "dc01" `
    -Credential $cred
```

PowerShell Direct non dipende dalla connettività IP tra host e guest e resta anche un percorso di emergenza locale.

## 4. Configurare hostname, rete e OpenSSH

**Macchina:** `dc01`  
**Collegamento consigliato:** PowerShell Direct  
**Shell:** PowerShell

Il blocco operativo validato è raccolto in:

`powershell/02-configure-dc01-base.ps1`

Lo script:

- individua la NIC attiva;
- imposta il nome `dc01`;
- disabilita DHCP;
- assegna `10.77.0.80/24`;
- imposta il gateway `10.77.0.1`;
- imposta il DNS iniziale `10.77.0.10`;
- imposta `W. Europe Standard Time`;
- avvia `sshd` e lo rende automatico;
- verifica/crea la regola firewall TCP/22;
- imposta PowerShell come shell predefinita di OpenSSH;
- porta il profilo della rete attiva a `Private`.

La rinomina del computer richiede un riavvio per diventare effettiva. Il file non esegue automaticamente il reboot.

Verifica minima:

```powershell
Get-Service sshd
Get-NetTCPConnection -LocalPort 22 -State Listen

Get-NetConnectionProfile |
    Format-Table InterfaceAlias,Name,NetworkCategory,IPv4Connectivity
```

### Troubleshooting — SSH non raggiungibile

Nel laboratorio la scheda Ethernet risultava inizialmente associata a una rete non identificata con profilo `Public`. La regola OpenSSH era invece prevista per il profilo `Private`, quindi il collegamento dall'host andava in timeout.

La correzione è:

```powershell
Set-NetConnectionProfile `
    -InterfaceAlias "Ethernet" `
    -NetworkCategory Private
```

Dopo il cambio di profilo la sessione SSH ha funzionato regolarmente.

## 5. Verificare il primo accesso SSH

Dal PC amministrativo:

```powershell
ssh Administrator@10.77.0.80
```

Dopo il login:

```powershell
hostname
```

Risultato atteso:

```text
dc01
```

## 6. Installare la chiave pubblica Ed25519 per Administrator

La coppia di chiavi viene generata sul PC amministrativo:

```powershell
$sshDir = "$env:USERPROFILE\.ssh"

New-Item `
    -ItemType Directory `
    -Path $sshDir `
    -Force | Out-Null

ssh-keygen `
    -t ed25519 `
    -f "$sshDir\dc01_ed25519" `
    -C "dc01-lab"
```

La chiave privata `dc01_ed25519` resta esclusivamente sul PC amministrativo.

Trasferire sul server soltanto la chiave pubblica:

```powershell
scp `
    "$env:USERPROFILE\.ssh\dc01_ed25519.pub" `
    Administrator@10.77.0.80:dc01_ed25519.pub
```

Su `dc01`, durante l'ultima sessione autenticata con password, eseguire:

`powershell/03-authorize-admin-ssh-key.ps1`

Il file installa la chiave in:

```text
C:\ProgramData\ssh\administrators_authorized_keys
```

e imposta ACL limitate a:

```text
NT AUTHORITY\SYSTEM:(F)
BUILTIN\Administrators:(F)
```

Prima di chiudere la sessione esistente, da un secondo terminale:

```powershell
ssh `
    -i "$env:USERPROFILE\.ssh\dc01_ed25519" `
    -o IdentitiesOnly=yes `
    Administrator@10.77.0.80
```

Il test è positivo quando la sessione PowerShell si apre senza richiedere la password.

L'autenticazione a password resta abilitata come fallback durante la successiva costruzione del Domain Controller.

## 7. Alias SSH opzionale sul client

Nel file:

```text
%USERPROFILE%\.ssh\config
```

può essere aggiunta la voce:

```text
Host dc01
    HostName 10.77.0.80
    User Administrator
    IdentityFile ~/.ssh/dc01_ed25519
    IdentitiesOnly yes
```

Il collegamento diventa quindi:

```powershell
ssh dc01
```

## 8. Attivare e verificare Windows Server Evaluation

In una sessione SSH, `slmgr.vbs` eseguito direttamente può non produrre testo in console. Per forzare l'output testuale usare `cscript.exe`:

```powershell
cscript.exe //nologo C:\Windows\System32\slmgr.vbs /dlv
cscript.exe //nologo C:\Windows\System32\slmgr.vbs /xpr
```

Nel laboratorio lo stato validato è:

- edizione: `ServerStandardEval`;
- licenza: attiva;
- scadenza Evaluation: **18/05/2027 18:07:30**.

### Troubleshooting — slmgr.vbs non mostra output via SSH

I comandi:

```powershell
slmgr.vbs /dlv
slmgr.vbs /ato
```

non hanno mostrato output nella sessione remota.

La forma console corretta è:

```powershell
cscript.exe //nologo C:\Windows\System32\slmgr.vbs /dlv
cscript.exe //nologo C:\Windows\System32\slmgr.vbs /ato
cscript.exe //nologo C:\Windows\System32\slmgr.vbs /xpr
```

## Stato finale di questa prima fase

Al termine di questa pubblicazione GitHub lo stato validato è:

- `dc01` installato e configurato;
- IP statico `10.77.0.80/24`;
- DNS iniziale `10.77.0.10`;
- profilo rete `Private`;
- OpenSSH attivo;
- accesso PowerShell via SSH verificato;
- autenticazione con chiave Ed25519 verificata;
- Evaluation attiva;
- DNS parent **non ancora modificato**;
- AD DS **non ancora installato**.

La fase successiva inizierà con la registrazione di `dc01.ad.lab.test` nel DNS parent su `infra01`, seguita dal checkpoint pre-promozione e dall'installazione di AD DS. Questi materiali verranno aggiunti soltanto dopo la validazione reale del laboratorio.

## Materiale escluso dal repository

Non versionare:

- password dell'account `Administrator`;
- `dc01_ed25519`, la chiave privata SSH;
- chiavi private o secret futuri del dominio;
- file `known_hosts` personali;
- backup o checkpoint contenenti credenziali;
- configurazioni utente contenenti dati non necessari alla replicabilità.

La chiave pubblica generata per uno specifico PC amministrativo non è necessaria nel repository: viene creata durante il laboratorio.
