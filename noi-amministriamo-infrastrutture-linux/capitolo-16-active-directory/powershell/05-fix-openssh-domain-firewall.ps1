# Capitolo 16 - OpenSSH dopo la promozione a Domain Controller
# Eseguire su dc01 tramite PowerShell Direct se SSH non e' raggiungibile.

Get-Service sshd
Get-NetConnectionProfile

Get-NetFirewallRule `
    -Name "OpenSSH-Server-In-TCP" |
    Format-List Enabled,Profile,Direction,Action

Set-NetFirewallRule `
    -Name "OpenSSH-Server-In-TCP" `
    -Profile Domain,Private
