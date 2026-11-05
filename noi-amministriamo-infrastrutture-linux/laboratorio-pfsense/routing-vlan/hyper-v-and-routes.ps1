# pfSense - trunk Hyper-V e route Windows
Set-VMNetworkAdapterVlan `
    -VMName "pfsense01" `
    -VMNetworkAdapterName "LAN" `
    -Trunk `
    -AllowedVlanIdList "10,20" `
    -NativeVlanId 0

Get-VMNetworkAdapterVlan -VMName "pfsense01"

New-NetRoute -DestinationPrefix "10.88.10.0/24" `
    -InterfaceAlias "vEthernet (PFSENSE-LAN)" `
    -NextHop "10.88.0.1"

New-NetRoute -DestinationPrefix "10.88.20.0/24" `
    -InterfaceAlias "vEthernet (PFSENSE-LAN)" `
    -NextHop "10.88.0.1"
