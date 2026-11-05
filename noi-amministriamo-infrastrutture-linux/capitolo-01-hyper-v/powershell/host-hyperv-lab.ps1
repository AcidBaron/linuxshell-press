# Capitolo 1 - Host Hyper-V e creazione fw01
# Eseguire da PowerShell amministrativa.
# Verificare prima percorsi, ISO e presenza delle funzionalità Hyper-V.

systeminfo

Get-WindowsOptionalFeature -Online |
    Where-Object FeatureName -like '*Hyper-V*' |
    Select-Object FeatureName, State

Get-Service vmms
Get-Command virtmgmt.msc

Get-PhysicalDisk |
    Select-Object FriendlyName,MediaType,BusType,@{N='SizeGB';E={[math]::Round($_.Size/1GB,1)}},HealthStatus

Get-Partition |
    Where-Object DriveLetter -in @('C','E','F','M') |
    ForEach-Object {
        $p = $_
        $d = Get-Disk -Number $p.DiskNumber
        [PSCustomObject]@{
            DriveLetter = $p.DriveLetter
            DiskNumber  = $d.Number
            DiskName    = $d.FriendlyName
            BusType     = $d.BusType
            SizeGB      = [math]::Round($d.Size/1GB,1)
        }
    }

New-Item -ItemType Directory -Force -Path `
    'E:\Hyper-V\VMs',`
    'E:\Hyper-V\VHDX',`
    'E:\Hyper-V\ISO',`
    'E:\Hyper-V\Templates',`
    'E:\Hyper-V\Exports',`
    'E:\Hyper-V\Labs' | Out-Null

Set-VMHost `
    -VirtualMachinePath 'E:\Hyper-V\VMs' `
    -VirtualHardDiskPath 'E:\Hyper-V\VHDX'

Get-VMHost |
    Select-Object VirtualMachinePath,VirtualHardDiskPath

New-VMSwitch -Name 'LAB-LAN' -SwitchType Internal

New-NetIPAddress `
    -InterfaceAlias 'vEthernet (LAB-LAN)' `
    -IPAddress 10.77.0.254 `
    -PrefixLength 24

Get-NetIPAddress `
    -InterfaceAlias 'vEthernet (LAB-LAN)' `
    -AddressFamily IPv4 |
    Select-Object InterfaceAlias,IPAddress,PrefixLength,AddressState,PrefixOrigin

Get-VMSwitch | Select-Object Name,SwitchType

& {
    $VMName = 'fw01'
    $VHD = 'E:\Hyper-V\VHDX\fw01.vhdx'
    $ISO = 'E:\Hyper-V\ISO\ubuntu-24.04.5-live-server-amd64.iso'

    New-VM `
        -Name $VMName `
        -Generation 2 `
        -MemoryStartupBytes 2GB `
        -NewVHDPath $VHD `
        -NewVHDSizeBytes 20GB `
        -SwitchName 'Default Switch'

    Set-VMProcessor -VMName $VMName -Count 2

    Set-VMMemory `
        -VMName $VMName `
        -DynamicMemoryEnabled $true `
        -MinimumBytes 1GB `
        -StartupBytes 2GB `
        -MaximumBytes 4GB

    Set-VMFirmware `
        -VMName $VMName `
        -EnableSecureBoot On `
        -SecureBootTemplate 'MicrosoftUEFICertificateAuthority'

    Add-VMNetworkAdapter `
        -VMName $VMName `
        -SwitchName 'LAB-LAN' `
        -Name 'LAN'

    Add-VMDvdDrive `
        -VMName $VMName `
        -Path $ISO
}

Rename-VMNetworkAdapter `
    -VMName 'fw01' `
    -Name 'Scheda di rete' `
    -NewName 'WAN'

& {
    $dvd = Get-VMDvdDrive -VMName 'fw01'
    Set-VMFirmware -VMName 'fw01' -FirstBootDevice $dvd
    Set-VM -Name 'fw01' -AutomaticCheckpointsEnabled $false
}

Start-VM -Name 'fw01'
vmconnect.exe localhost fw01
