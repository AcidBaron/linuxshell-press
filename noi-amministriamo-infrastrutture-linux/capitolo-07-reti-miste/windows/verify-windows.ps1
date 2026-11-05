# Capitolo 7 - verifica Windows LAB-LAN
Get-NetIPConfiguration -InterfaceAlias "vEthernet (LAB-LAN)" -Detailed
Get-NetIPAddress -InterfaceAlias "vEthernet (LAB-LAN)"
Get-NetRoute -InterfaceAlias "vEthernet (LAB-LAN)"

Resolve-DnsName fw01.lab.test -DnsOnly
Resolve-DnsName infra01.lab.test -DnsOnly
Resolve-DnsName dns.lab.test -DnsOnly
Resolve-DnsName www.microsoft.com -DnsOnly

Get-DnsClientNrptRule |
    Where-Object Namespace -contains ".lab.test"

Get-Service sshd
Get-NetTCPConnection -State Listen -LocalPort 22
Get-NetFirewallRule -Name "CH7-OpenSSH-LAB-LAN","OpenSSH-Server-In-TCP" |
    Select-Object Name,Enabled,Direction,Action,Profile

Get-NetFirewallRule -Name "CH7-OpenSSH-LAB-LAN" |
    Get-NetFirewallAddressFilter

Test-NetConnection 10.77.0.1 -Port 22
Test-NetConnection 10.77.0.101 -Port 22
