# Capitolo 7 - configurazione persistente Windows per LAB-LAN
# Eseguire da PowerShell amministrativa.

# Split-DNS selettivo per il namespace del laboratorio
Add-DnsClientNrptRule `
    -Namespace ".lab.test" `
    -NameServers "10.77.0.10" `
    -DisplayName "LAB-LAN lab.test via infra01" `
    -Comment "Linuxshell Press - Capitolo 7"

# OpenSSH Server
$cap = Get-WindowsCapability -Online |
    Where-Object Name -like 'OpenSSH.Server*'

if ($cap.State -ne 'Installed') {
    Add-WindowsCapability -Online -Name $cap.Name
}

# La regola automatica Microsoft non è adatta alla LAB-LAN Public/multi-homed.
Disable-NetFirewallRule -Name "OpenSSH-Server-In-TCP"

New-NetFirewallRule `
    -Name "CH7-OpenSSH-LAB-LAN" `
    -DisplayName "CH7 OpenSSH - LAB-LAN only" `
    -Enabled True -Direction Inbound -Action Allow `
    -Protocol TCP -LocalPort 22 `
    -InterfaceAlias "vEthernet (LAB-LAN)" `
    -RemoteAddress 10.77.0.0/24,fd3a:7b4c:2d91:1::/64 `
    -Profile Any

Set-Service -Name sshd -StartupType Automatic
Start-Service sshd

& "$env:WINDIR\System32\OpenSSH\sshd.exe" -t
