# Capitolo 1 - verifiche post-installazione e checkpoint
# Eseguire da PowerShell amministrativa sull'host.

Test-NetConnection 10.77.0.1 -Port 22
ssh labadmin@10.77.0.1

& {
    Stop-VM -Name 'fw01'
    $dvd = Get-VMDvdDrive -VMName 'fw01'
    Set-VMDvdDrive `
        -VMName 'fw01' `
        -ControllerNumber $dvd.ControllerNumber `
        -ControllerLocation $dvd.ControllerLocation `
        -Path $null
    Start-VM -Name 'fw01'
}

Get-VMNetworkAdapter -VMName 'fw01' |
    Select-Object Name,SwitchName,MacAddress,IPAddresses

Checkpoint-VM -Name 'fw01' `
    -SnapshotName 'BASE-OS-INSTALLED'

Get-VMSnapshot -VMName 'fw01' |
    Select-Object VMName,Name,CreationTime
