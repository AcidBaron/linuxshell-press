# Correzione boot post-installazione
Stop-VM -Name "pfsense01" -TurnOff
Get-VMDvdDrive -VMName "pfsense01" | Select-Object Path
$Disk = Get-VMHardDiskDrive -VMName "pfsense01"
Set-VMFirmware -VMName "pfsense01" -FirstBootDevice $Disk
(Get-VMFirmware -VMName "pfsense01").BootOrder |
    Select-Object BootType,Device,Description |
    Format-Table -AutoSize

# Verifica WebGUI
ping 10.88.0.1
Test-NetConnection -ComputerName 10.88.0.1 -Port 443

# Checkpoint pre-wizard
Checkpoint-VM `
    -Name "pfsense01" `
    -SnapshotName "PFSENSE-BASE-INSTALLED"

# Dopo il wizard
Checkpoint-VM `
    -Name "pfsense01" `
    -SnapshotName "PFSENSE-WIZARD-COMPLETE"

Get-VMSnapshot -VMName "pfsense01" |
    Select-Object VMName,Name,CreationTime |
    Format-Table -AutoSize
