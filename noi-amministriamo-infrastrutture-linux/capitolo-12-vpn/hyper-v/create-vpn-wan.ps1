# Helper di repository derivato dai comandi del paragrafo 12.2.
# Non era un file preesistente nel laboratorio: raccoglie in uno script
# i comandi PowerShell eseguiti e documentati nel capitolo.

Get-NetNat

Get-VMSwitch |
    Select-Object Name,SwitchType

Get-VMNetworkAdapter `
    -VMName "fw01" |
    Format-Table Name,SwitchName,Status -AutoSize

Get-NetRoute |
    Where-Object { $_.DestinationPrefix -like "10.250.*" }

New-VMSwitch `
    -Name "VPN-WAN" `
    -SwitchType Internal

$IfIndex = (
    Get-NetAdapter -Name "vEthernet (VPN-WAN)"
).ifIndex

New-NetIPAddress `
    -InterfaceIndex $IfIndex `
    -IPAddress 10.250.0.1 `
    -PrefixLength 24

New-NetNat `
    -Name "VPN-WAN-NAT" `
    -InternalIPInterfaceAddressPrefix 10.250.0.0/24

Get-NetIPAddress `
    -InterfaceAlias "vEthernet (VPN-WAN)" `
    -AddressFamily IPv4

Get-NetNat `
    -Name "VPN-WAN-NAT"

Connect-VMNetworkAdapter `
    -VMName "fw01" `
    -Name "WAN" `
    -SwitchName "VPN-WAN"
