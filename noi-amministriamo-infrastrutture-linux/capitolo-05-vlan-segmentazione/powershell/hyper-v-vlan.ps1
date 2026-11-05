# Capitolo 5 - trunk e porte Access Hyper-V

Checkpoint-VM -Name "fw01" -SnapshotName "CH5-PRE-VLAN"

Add-VMNetworkAdapter `
    -VMName "fw01" `
    -SwitchName "LAB-LAN" `
    -Name "VLAN-TRUNK"

Set-VMNetworkAdapterVlan `
    -VMName "fw01" `
    -VMNetworkAdapterName "VLAN-TRUNK" `
    -Trunk `
    -AllowedVlanIdList "10,20" `
    -NativeVlanId 0

Set-VMNetworkAdapterVlan `
    -VMName "vlan10-client01" `
    -Access `
    -VlanId 10

Set-VMNetworkAdapterVlan `
    -VMName "vlan20-client01" `
    -Access `
    -VlanId 20

Get-VMNetworkAdapterVlan `
    -VMName "fw01","vlan10-client01","vlan20-client01" |
    Format-Table -AutoSize
