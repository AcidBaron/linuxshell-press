# Capitolo 1 – Laboratorio di riferimento con Windows 11 e Hyper-V — comandi e configurazioni
> Estratto operativo dal master `Capitoli_01_02_Laboratorio_HyperV_Router_Firewall_REVISIONATI.docx`. I blocchi sono riportati nell'ordine del capitolo.

## 1.1 Perché Hyper-V e quale topologia vogliamo ottenere

```bash
Internet / rete host
        |
Hyper-V Default Switch
        |
      WAN eth0
       [fw01]
      LAN eth1 10.77.0.1/24
        |
      LAB-LAN 10.77.0.0/24
        |
 Host Windows 10.77.0.254/24
```

## 1.2 Verificare l’host prima di creare VM

```bash
systeminfo
```

```powershell
Get-WindowsOptionalFeature -Online |
Where-Object FeatureName -like '*Hyper-V*' |
Select-Object FeatureName, State

Get-Service vmms
Get-Command virtmgmt.msc
```

## 1.3 Inventariare lo storage e scegliere dove mettere le VM

```powershell
Get-PhysicalDisk |
Select-Object FriendlyName,MediaType,BusType,`
@{N='SizeGB';E={[math]::Round($_.Size/1GB,1)}},HealthStatus
```

```powershell
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
```

## 1.4 Preparare le directory Hyper-V

```powershell
New-Item -ItemType Directory -Force -Path `
'E:\Hyper-V\VMs',`
'E:\Hyper-V\VHDX',`
'E:\Hyper-V\ISO',`
'E:\Hyper-V\Templates',`
'E:\Hyper-V\Exports',`
'E:\Hyper-V\Labs' | Out-Null
```

```powershell
Set-VMHost `
  -VirtualMachinePath 'E:\Hyper-V\VMs' `
  -VirtualHardDiskPath 'E:\Hyper-V\VHDX'

Get-VMHost |
Select-Object VirtualMachinePath,VirtualHardDiskPath
```

## 1.5 Creare LAB-LAN e assegnare l’indirizzo all’host

```powershell
New-VMSwitch -Name 'LAB-LAN' -SwitchType Internal
```

```powershell
New-NetIPAddress `
  -InterfaceAlias 'vEthernet (LAB-LAN)' `
  -IPAddress 10.77.0.254 `
  -PrefixLength 24
```

```powershell
Get-NetIPAddress `
  -InterfaceAlias 'vEthernet (LAB-LAN)' `
  -AddressFamily IPv4 |
Select-Object InterfaceAlias,IPAddress,PrefixLength,AddressState,PrefixOrigin

Get-VMSwitch | Select-Object Name,SwitchType
```

## 1.6 Creare fw01

```powershell
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
```

## 1.7 Rendere leggibili le due NIC e il boot

```powershell
Rename-VMNetworkAdapter `
  -VMName 'fw01' `
  -Name 'Scheda di rete' `
  -NewName 'WAN'

& {
$dvd = Get-VMDvdDrive -VMName 'fw01'
Set-VMFirmware -VMName 'fw01' -FirstBootDevice $dvd
Set-VM -Name 'fw01' -AutomaticCheckpointsEnabled $false
}
```

## 1.8 Installare Ubuntu Server: distinguere WAN e LAN

```powershell
Start-VM -Name 'fw01'
vmconnect.exe localhost fw01
```

## 1.10 Primo boot: hostname, indirizzi e route

```bash
hostname
ip -br addr
ip route
```

## 1.11 Verifiche di connettività: separare LAN, Internet e DNS

```bash
# Verifica opzionale del collegamento con l’host Windows
ping -c 3 10.77.0.254

# Verifica della connettività IP sulla WAN
ping -c 3 1.1.1.1

# Verifica della risoluzione dei nomi
getent hosts archive.ubuntu.com
```

## 1.12 OpenSSH su Ubuntu 24.04: service e socket activation

```bash
dpkg -l openssh-server | grep '^ii'
systemctl status ssh.socket --no-pager
systemctl is-enabled ssh.socket
systemctl is-active ssh.socket
sudo ss -ltnp | grep ':22'
```

```powershell
Test-NetConnection 10.77.0.1 -Port 22
ssh labadmin@10.77.0.1
```

## 1.13 Rimuovere l’ISO e mappare i MAC

```powershell
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
```

```powershell
Get-VMNetworkAdapter -VMName 'fw01' |
Select-Object Name,SwitchName,MacAddress,IPAddresses
```

## 1.14 Salvare la baseline: checkpoint BASE-OS-INSTALLED

```powershell
Checkpoint-VM -Name 'fw01' `
  -SnapshotName 'BASE-OS-INSTALLED'

Get-VMSnapshot -VMName 'fw01' |
Select-Object VMName,Name,CreationTime
```
