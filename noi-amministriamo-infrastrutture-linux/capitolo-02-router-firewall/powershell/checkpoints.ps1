# Capitolo 2 - checkpoint finali
Checkpoint-VM -Name 'fw01' `
    -SnapshotName 'ROUTER-FIREWALL-VALIDATED'

Checkpoint-VM -Name 'linux-client01' `
    -SnapshotName 'LAB-LAN-CLIENT-VALIDATED'

Get-VMSnapshot -VMName 'fw01','linux-client01' |
    Select-Object VMName,Name,CreationTime
