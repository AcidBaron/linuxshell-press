# Capitolo 8 - checkpoint prima del reboot finale
Checkpoint-VM -Name "files01" `
    -SnapshotName "CH8-SAMBA-PRE-REBOOT"

Get-VMSnapshot -VMName "files01" |
    Select-Object VMName,Name,CreationTime
