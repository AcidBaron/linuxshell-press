# Windows -> Linux: file, SHA-256, SCP
"Capitolo 7 - trasferimento OpenSSH Windows verso Linux" |
    Set-Content "$env:TEMP\ch7-windows-to-linux.txt"

Get-FileHash "$env:TEMP\ch7-windows-to-linux.txt" -Algorithm SHA256
scp "$env:TEMP\ch7-windows-to-linux.txt" labadmin@linux-client01.lab.test:/tmp/

# Sessione SFTP interattiva
sftp labadmin@linux-client01.lab.test
