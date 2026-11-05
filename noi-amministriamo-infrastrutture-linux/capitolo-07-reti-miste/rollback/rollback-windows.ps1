# Capitolo 7 - rollback selettivo Windows
# Non rimuove policy Tailscale o altri namespace NRPT.

Remove-NetFirewallRule -Name "CH7-OpenSSH-LAB-LAN" -ErrorAction SilentlyContinue

# Riabilitare la regola Microsoft solo se si vuole tornare al comportamento pre-lab.
Enable-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue

Stop-Service sshd -ErrorAction SilentlyContinue
Set-Service sshd -StartupType Manual

# Rimuovere OpenSSH Server soltanto se il rollback deve eliminare anche la capability.
# Remove-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

# Individuare la sola regola .lab.test prima della rimozione.
Get-DnsClientNrptRule | Where-Object Namespace -contains ".lab.test"
