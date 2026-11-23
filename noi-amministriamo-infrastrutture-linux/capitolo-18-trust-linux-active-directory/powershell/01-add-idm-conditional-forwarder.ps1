# Capitolo 18 - DNS AD verso IdM
# Eseguire su dc01 da PowerShell amministrativa.

Add-DnsServerConditionalForwarderZone `
    -Name "idm.lab.test" `
    -MasterServers 10.77.0.70 `
    -ReplicationScope Forest `
    -PassThru

Resolve-DnsName `
    _kerberos._udp.idm.lab.test `
    -Type SRV `
    -Server 127.0.0.1
