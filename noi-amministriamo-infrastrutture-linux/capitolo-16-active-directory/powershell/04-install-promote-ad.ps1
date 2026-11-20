# Capitolo 16 - Installazione AD DS e promozione del primo Domain Controller
# Eseguire su dc01 da PowerShell amministrativa.

Install-WindowsFeature `
    AD-Domain-Services `
    -IncludeManagementTools

$dsrm = ConvertTo-SecureString `
    "123456Aa!" `
    -AsPlainText `
    -Force

Install-ADDSForest `
    -DomainName "ad.lab.test" `
    -DomainNetbiosName "AD" `
    -DomainMode Win2025 `
    -ForestMode Win2025 `
    -InstallDns:$true `
    -CreateDnsDelegation:$false `
    -SafeModeAdministratorPassword $dsrm `
    -Force:$true
