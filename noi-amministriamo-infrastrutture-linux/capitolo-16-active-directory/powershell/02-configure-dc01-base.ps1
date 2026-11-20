# Capitolo 16 - Configurazione base di dc01
# Macchina: dc01
# Collegamento consigliato: PowerShell Direct
# Shell: PowerShell
# Verificato nel laboratorio del 19 novembre 2026.
#
# Nota: il blocco modifica la configurazione IP della NIC.
# Eseguirlo da PowerShell Direct, non da una sessione di rete.
# La rinomina richiede un riavvio per diventare effettiva.
# Il riavvio non viene eseguito automaticamente.

$nic = Get-NetAdapter |
    Where-Object Status -eq "Up" |
    Select-Object -First 1

$nic |
    Format-Table Name,InterfaceDescription,IfIndex,Status

Rename-Computer -NewName "dc01"

Set-NetIPInterface `
    -InterfaceIndex $nic.ifIndex `
    -Dhcp Disabled

Get-NetIPAddress `
    -InterfaceIndex $nic.ifIndex `
    -AddressFamily IPv4 `
    -ErrorAction SilentlyContinue |
    Remove-NetIPAddress -Confirm:$false

Get-NetRoute `
    -InterfaceIndex $nic.ifIndex `
    -AddressFamily IPv4 `
    -ErrorAction SilentlyContinue |
    Where-Object DestinationPrefix -eq "0.0.0.0/0" |
    Remove-NetRoute -Confirm:$false

New-NetIPAddress `
    -InterfaceIndex $nic.ifIndex `
    -IPAddress "10.77.0.80" `
    -PrefixLength 24 `
    -DefaultGateway "10.77.0.1"

Set-DnsClientServerAddress `
    -InterfaceIndex $nic.ifIndex `
    -ServerAddresses "10.77.0.10"

Set-TimeZone -Id "W. Europe Standard Time"

Start-Service sshd

Set-Service `
    -Name sshd `
    -StartupType Automatic

if (!(Get-NetFirewallRule `
    -Name "OpenSSH-Server-In-TCP" `
    -ErrorAction SilentlyContinue)) {

    New-NetFirewallRule `
        -Name "OpenSSH-Server-In-TCP" `
        -DisplayName "OpenSSH Server (sshd)" `
        -Enabled True `
        -Direction Inbound `
        -Protocol TCP `
        -Action Allow `
        -LocalPort 22
}

New-ItemProperty `
    -Path "HKLM:\SOFTWARE\OpenSSH" `
    -Name "DefaultShell" `
    -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -PropertyType String `
    -Force

$profile = Get-NetConnectionProfile |
    Where-Object InterfaceIndex -eq $nic.ifIndex |
    Select-Object -First 1

if ($profile.NetworkCategory -ne "Private") {
    Set-NetConnectionProfile `
        -InterfaceIndex $nic.ifIndex `
        -NetworkCategory Private
}

# Verifica minima
Get-Service sshd
Get-NetTCPConnection -LocalPort 22 -State Listen

Get-NetConnectionProfile |
    Format-Table InterfaceAlias,Name,NetworkCategory,IPv4Connectivity

Get-NetIPConfiguration
Get-DnsClientServerAddress -InterfaceIndex $nic.ifIndex

Write-Host
Write-Host "Configurazione base completata."
Write-Host "Riavviare dc01 prima della verifica finale del nuovo hostname."
