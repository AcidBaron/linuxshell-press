# Capitolo 2 - creazione linux-client01
# Eseguire da PowerShell amministrativa.

& {
    $VMName = 'linux-client01'
    $VHD = 'E:\Hyper-V\VHDX\linux-client01.vhdx'
    $ISO = 'E:\Hyper-V\ISO\ubuntu-24.04.5-live-server-amd64.iso'

    New-VM `
        -Name $VMName `
        -Generation 2 `
        -MemoryStartupBytes 2GB `
        -NewVHDPath $VHD `
        -NewVHDSizeBytes 20GB `
        -SwitchName 'LAB-LAN'

    Set-VMProcessor -VMName $VMName -Count 2
    Set-VMMemory -VMName $VMName `
        -DynamicMemoryEnabled $true `
        -MinimumBytes 1GB `
        -StartupBytes 2GB `
        -MaximumBytes 4GB

    Set-VMFirmware -VMName $VMName `
        -EnableSecureBoot On `
        -SecureBootTemplate 'MicrosoftUEFICertificateAuthority'

    Add-VMDvdDrive -VMName $VMName -Path $ISO
    $dvd = Get-VMDvdDrive -VMName $VMName
    Set-VMFirmware -VMName $VMName -FirstBootDevice $dvd
    Set-VM -Name $VMName -AutomaticCheckpointsEnabled $false
}

Get-VMNetworkAdapter -VMName 'linux-client01' |
    Select-Object Name,SwitchName,MacAddress

# Configurazione IPv4 usata durante l'installazione guest:
#   address: 10.77.0.101/24
#   gateway: 10.77.0.1
#   DNS: 1.1.1.1, 8.8.8.8
#   hostname: linux-client01
