# Capitolo 16 - Creazione della VM dc01
# Macchina: host Windows 11
# Shell: PowerShell amministrativa
# Verificato nel laboratorio del 19 novembre 2026.

$IsoPath = "E:\Hyper-V\ISO\26100.32230.260111-0550.1t_release_svc_refresh_SERVER_EVAL_x64FRE_it-it.iso"

New-VM `
    -Name "dc01" `
    -Generation 2 `
    -MemoryStartupBytes 4GB `
    -Path "E:\Hyper-V\VMs" `
    -NewVHDPath "E:\Hyper-V\VHDX\dc01.vhdx" `
    -NewVHDSizeBytes 40GB `
    -SwitchName "LAB-LAN"

Set-VMProcessor -VMName "dc01" -Count 2

Set-VMMemory `
    -VMName "dc01" `
    -DynamicMemoryEnabled $true `
    -MinimumBytes 2GB `
    -StartupBytes 4GB `
    -MaximumBytes 8GB

Set-VM `
    -Name "dc01" `
    -AutomaticCheckpointsEnabled $false

Add-VMDvdDrive -VMName "dc01" -Path $IsoPath
$Dvd = Get-VMDvdDrive -VMName "dc01"

Set-VMFirmware `
    -VMName "dc01" `
    -FirstBootDevice $Dvd

# Verifica minima
Get-VM "dc01" |
    Format-List Name,State,Generation,Path,MemoryStartup

Get-VMHardDiskDrive "dc01" |
    Format-Table Path

Get-VMNetworkAdapter "dc01" |
    Format-Table Name,SwitchName,Status

Get-VMDvdDrive "dc01" |
    Format-Table Path
