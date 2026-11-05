# pfSense - setup iniziale Hyper-V
New-VMSwitch `
    -Name "PFSENSE-LAN" `
    -SwitchType Internal

New-NetIPAddress `
    -InterfaceAlias "vEthernet (PFSENSE-LAN)" `
    -IPAddress 10.88.0.254 `
    -PrefixLength 24

$VMName = "pfsense01"
$VMPath = "E:\Hyper-V\VMs"
$VHDPath = "E:\Hyper-V\VHDX\pfsense01.vhdx"
$ISOPath = "E:\Hyper-V\ISO\netgate-installer-v1.2-RELEASE-amd64.iso"

New-VM `
    -Name $VMName `
    -Generation 2 `
    -MemoryStartupBytes 2GB `
    -NewVHDPath $VHDPath `
    -NewVHDSizeBytes 20GB `
    -Path $VMPath `
    -SwitchName "Default Switch"

Set-VMProcessor -VMName $VMName -Count 2
Set-VM -Name $VMName -AutomaticCheckpointsEnabled $false -AutomaticStartAction Nothing
Set-VMFirmware -VMName $VMName -EnableSecureBoot Off

$WanNic = Get-VMNetworkAdapter -VMName $VMName | Select-Object -First 1
Rename-VMNetworkAdapter -VMNetworkAdapter $WanNic -NewName "WAN"

Add-VMNetworkAdapter `
    -VMName $VMName `
    -SwitchName "PFSENSE-LAN" `
    -Name "LAN"

Add-VMDvdDrive `
    -VMName $VMName `
    -Path $ISOPath

Start-VM -Name "pfsense01"
Start-Sleep -Seconds 5
Get-VMNetworkAdapter -VMName "pfsense01" |
    Select-Object Name,SwitchName,MacAddress,Status |
    Format-Table -AutoSize
