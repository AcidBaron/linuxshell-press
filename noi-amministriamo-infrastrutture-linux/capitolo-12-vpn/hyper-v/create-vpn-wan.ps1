# Capitolo 12 - creazione VPN-WAN per il laboratorio Hyper-V
# Eseguire da PowerShell come amministratore.

$ErrorActionPreference = "Stop"
$SwitchName = "VPN-WAN"
$NatName = "VPN-WAN-NAT"
$Gateway = "10.250.0.1"
$Prefix = "10.250.0.0/24"

Write-Host "=== Preflight ==="
Get-NetNat
Get-VMSwitch | Select-Object Name,SwitchType
Get-NetRoute | Where-Object { $_.DestinationPrefix -like "10.250.*" }

if (Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue) {
    throw "Lo switch $SwitchName esiste gia'. Verificare lo stato prima di proseguire."
}
if (Get-NetNat -Name $NatName -ErrorAction SilentlyContinue) {
    throw "Il NAT $NatName esiste gia'. Verificare lo stato prima di proseguire."
}

New-VMSwitch -Name $SwitchName -SwitchType Internal

$IfIndex = (Get-NetAdapter -Name "vEthernet ($SwitchName)").ifIndex

New-NetIPAddress -InterfaceIndex $IfIndex -IPAddress $Gateway -PrefixLength 24

New-NetNat -Name $NatName -InternalIPInterfaceAddressPrefix $Prefix

Get-NetIPAddress -InterfaceAlias "vEthernet ($SwitchName)" -AddressFamily IPv4
Get-NetNat -Name $NatName | Format-List Name,InternalIPInterfaceAddressPrefix,Active

Write-Host "VPN-WAN creata. Collegare soltanto l'adapter WAN di fw01 allo switch VPN-WAN."