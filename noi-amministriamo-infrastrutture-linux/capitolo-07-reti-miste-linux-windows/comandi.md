# Capitolo 7 – Reti miste Linux e Windows — comandi e configurazioni
> Estratto operativo dal master `Capitolo_07_Reti_miste_Linux_e_Windows(1).docx`. I blocchi sono riportati nell'ordine del capitolo.

## 7.1 Scenario e baseline del laboratorio

```powershell
Get-NetIPConfiguration -InterfaceAlias "vEthernet (LAB-LAN)" -Detailed
Get-NetIPAddress -InterfaceAlias "vEthernet (LAB-LAN)"
Get-NetRoute -InterfaceAlias "vEthernet (LAB-LAN)"
```

## 7.3 DNS Linux visto da Windows

```powershell
Resolve-DnsName fw01.lab.test -Server 10.77.0.10 -DnsOnly
Resolve-DnsName infra01.lab.test -Server 10.77.0.10 -DnsOnly
```

## 7.3.1 Split-DNS con NRPT

```powershell
Add-DnsClientNrptRule `
    -Namespace ".lab.test" `
    -NameServers "10.77.0.10" `
    -DisplayName "LAB-LAN lab.test via infra01" `
    -Comment "Linuxshell Press - Capitolo 7"
```

## 7.3.2 FQDN, nomi corti e fallback locali

```powershell
Resolve-DnsName fw01 -DnsOnly
Resolve-DnsName fw01 -LlmnrOnly
Resolve-DnsName fw01 -LlmnrNetbiosOnly
# tutti FAIL/TIMEOUT nel laboratorio
```

## 7.4 OpenSSH da Windows verso Linux

```bash
systemctl is-enabled ssh.socket
systemctl is-active ssh.socket
systemctl status ssh.socket --no-pager
systemctl status ssh.service --no-pager
```

```bash
ssh -4 labadmin@linux-client01.lab.test
```

```powershell
Resolve-DnsName linux-client01.lab.test -Type A -DnsOnly
# 10.77.0.101

Resolve-DnsName linux-client01.lab.test -Type AAAA -DnsOnly
# NODATA: zona esistente, nessun AAAA
```

```bash
ssh -6 labadmin@fd3a:7b4c:2d91:1:215:5dff:fe01:703
```

## 7.4.1 SCP e SFTP Windows → Linux

```powershell
"Capitolo 7 - trasferimento OpenSSH Windows verso Linux" |
    Set-Content "$env:TEMP\ch7-windows-to-linux.txt"

Get-FileHash "$env:TEMP\ch7-windows-to-linux.txt" -Algorithm SHA256
scp "$env:TEMP\ch7-windows-to-linux.txt" labadmin@linux-client01.lab.test:/tmp/
```

## 7.5 OpenSSH da Linux verso Windows

```powershell
$cap = Get-WindowsCapability -Online |
    Where-Object Name -like 'OpenSSH.Server*'

Add-WindowsCapability -Online -Name $cap.Name
```

## 7.5.1 Firewall: limitare SSH alla LAB-LAN

```powershell
Disable-NetFirewallRule -Name "OpenSSH-Server-In-TCP"

New-NetFirewallRule `
    -Name "CH7-OpenSSH-LAB-LAN" `
    -DisplayName "CH7 OpenSSH - LAB-LAN only" `
    -Enabled True -Direction Inbound -Action Allow `
    -Protocol TCP -LocalPort 22 `
    -InterfaceAlias "vEthernet (LAB-LAN)" `
    -RemoteAddress 10.77.0.0/24,fd3a:7b4c:2d91:1::/64 `
    -Profile Any
```

```powershell
Set-Service -Name sshd -StartupType Automatic
Start-Service sshd
& "$env:WINDIR\System32\OpenSSH\sshd.exe" -t
```

## 7.5.2 Login Linux → Windows in dual-stack

```bash
ssh Utente@10.77.0.254
ssh Utente@fd3a:7b4c:2d91:1:c1f1:f445:e784:4ff4
```

## A.3 Rollback Windows

```powershell
# Firewall dedicato
Remove-NetFirewallRule -Name "CH7-OpenSSH-LAB-LAN"
Enable-NetFirewallRule -Name "OpenSSH-Server-In-TCP"   # solo se si vuole ripristinare la regola Microsoft

# OpenSSH Server
Stop-Service sshd
Set-Service sshd -StartupType Manual
Remove-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

# NRPT: individuare prima la regola .lab.test
Get-DnsClientNrptRule | Where-Object Namespace -contains ".lab.test"
```
