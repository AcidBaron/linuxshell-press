# Capitolo 16 - Autorizzazione della chiave SSH per Administrator
# Macchina: dc01
# Shell: PowerShell
# Prerequisito:
#   C:\Users\Administrator\dc01_ed25519.pub
# deve contenere la chiave pubblica trasferita dal PC amministrativo.
#
# La chiave privata dc01_ed25519 NON deve essere copiata sul server
# e NON deve essere versionata nel repository.

$PublicKeyPath = "$env:USERPROFILE\dc01_ed25519.pub"
$AuthorizedKeys = "$env:ProgramData\ssh\administrators_authorized_keys"

if (-not (Test-Path $PublicKeyPath)) {
    throw "Chiave pubblica non trovata: $PublicKeyPath"
}

$pub = (Get-Content $PublicKeyPath -Raw).Trim()

if (-not (Test-Path $AuthorizedKeys)) {
    New-Item `
        -ItemType File `
        -Path $AuthorizedKeys `
        -Force | Out-Null
}

if ((Get-Content $AuthorizedKeys -ErrorAction SilentlyContinue) -notcontains $pub) {
    Add-Content `
        -Path $AuthorizedKeys `
        -Value $pub `
        -Encoding ascii
}

icacls.exe `
    $AuthorizedKeys `
    /inheritance:r `
    /grant "*S-1-5-32-544:F" `
    /grant "*S-1-5-18:F"

icacls.exe $AuthorizedKeys

Remove-Item $PublicKeyPath

Write-Host
Write-Host "Chiave pubblica installata."
Write-Host "Prima di chiudere la sessione corrente, verificare il login da un secondo terminale."
