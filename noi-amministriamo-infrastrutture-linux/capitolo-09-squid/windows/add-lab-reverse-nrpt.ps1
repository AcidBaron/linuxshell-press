# Capitolo 9 - split DNS reverse per LAB-LAN
# Eseguire in PowerShell amministrativa.

$ReverseNamespace = ".0.77.10.in-addr.arpa"

$Existing = Get-DnsClientNrptRule |
    Where-Object { $_.Namespace -contains $ReverseNamespace }

if ($Existing) {
    Write-Host "Reverse NRPT already present:"
    $Existing |
        Select-Object Name,Namespace,NameServers,DisplayName,Comment |
        Format-List
}
else {
    Add-DnsClientNrptRule `
        -Namespace $ReverseNamespace `
        -NameServers "10.77.0.10" `
        -DisplayName "LAB-LAN reverse 10.77.0.0-24 via infra01" `
        -Comment "Linuxshell Press - Capitolo 9" `
        -PassThru |
        Select-Object Name,Namespace,NameServers,DisplayName,Comment
}

Clear-DnsClientCache

Resolve-DnsName 10.77.0.40 -Type PTR -DnsOnly
