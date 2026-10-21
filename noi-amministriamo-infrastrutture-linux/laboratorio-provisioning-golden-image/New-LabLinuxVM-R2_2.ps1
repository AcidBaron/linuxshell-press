[CmdletBinding()]
param (
    [string]$Name,
    [string]$IPAddress,
    [int]$Prefix = 24,
    [string]$Gateway,
    [string]$DNS1 = "",
    [string]$DNS2 = "",
    [string]$SearchDomain = "lab.test",
    [string]$FinalSwitch = "LAB-LAN",
    [Nullable[int]]$VlanId = $null,

    [string]$ProvisioningSwitch = "LAB-LAN",
    [string]$ProvisioningIP = "10.77.0.100",
    [string]$ProvisioningHost = "ubuntu2404-base",
    [string]$GuestInterface = "eth0",
    [string]$SSHUser = "labadmin",
    [string]$GuestGeneralizeScript = "/usr/local/sbin/generalize-lab-clone-r2.sh",

    [string]$TemplateVM = "ubuntu2404-base-r2",
    [string]$TemplateVHD =
        "E:\Hyper-V\VHDX\ubuntu2404-base-r2\ubuntu2404-base-r2.vhdx",

    [string]$VMRoot = "E:\Hyper-V\VMs",
    [string]$VHDRoot = "E:\Hyper-V\VHDX",

    [int]$ProcessorCount = 2,
    [int]$StartupMemoryMB = 2048,
    [int]$MinimumMemoryMB = 1024,
    [int]$MaximumMemoryMB = 4096,

    [int]$SSHWaitSeconds = 180,
    [int]$PowerOffWaitSeconds = 120,
    [int]$FinalSSHWaitSeconds = 120,

    [switch]$NonInteractive,
    [switch]$SkipFinalSSHCheck,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Section {
    param([Parameter(Mandatory = $true)][string]$Title)
    Write-Host
    Write-Host "=== $Title ==="
}

function Read-Value {
    param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        [AllowEmptyString()][string]$Default = "",
        [switch]$AllowEmpty
    )

    while ($true) {
        if ([string]::IsNullOrWhiteSpace($Default)) {
            $Value = Read-Host "$Prompt"
        }
        else {
            $Value = Read-Host "$Prompt [$Default]"
            if ([string]::IsNullOrWhiteSpace($Value)) {
                $Value = $Default
            }
        }

        if ($AllowEmpty -or -not [string]::IsNullOrWhiteSpace($Value)) {
            return $Value.Trim()
        }

        Write-Host "Valore obbligatorio." -ForegroundColor Yellow
    }
}

function Read-OptionalValue {
    param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        [AllowEmptyString()][string]$Default = ""
    )

    $DisplayDefault = $Default
    if ([string]::IsNullOrWhiteSpace($DisplayDefault)) {
        $DisplayDefault = "<nessuno>"
    }

    $Value = Read-Host "$Prompt [$DisplayDefault] (none = vuoto)"

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $Default
    }

    if ($Value.Trim().ToLowerInvariant() -in @("none", "nessuno", "-")) {
        return ""
    }

    return $Value.Trim()
}

function Read-YesNo {
    param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        [bool]$Default = $false
    )

    $Suffix = if ($Default) { "[Y/n]" } else { "[y/N]" }
    $Answer = Read-Host "$Prompt $Suffix"

    if ([string]::IsNullOrWhiteSpace($Answer)) {
        return $Default
    }

    switch -Regex ($Answer.Trim().ToLowerInvariant()) {
        '^(y|yes|s|si)$' { return $true }
        '^(n|no)$'       { return $false }
        default          { return $Default }
    }
}

function Convert-IPv4ToInteger {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Address
    )

    $Parts = $Address.Split('.')

    if ($Parts.Count -ne 4) {
        throw "IPv4 non valido: $Address. Usare quattro ottetti."
    }

    $Values = @()

    foreach ($Part in $Parts) {
        $Octet = 0

        if (
            -not [int]::TryParse($Part, [ref]$Octet) -or
            $Octet -lt 0 -or
            $Octet -gt 255
        ) {
            throw "IPv4 non valido: $Address"
        }

        $Values += $Octet
    }

    return [uint64](
        ($Values[0] * 16777216) +
        ($Values[1] * 65536) +
        ($Values[2] * 256) +
        $Values[3]
    )
}

function Convert-IntegerToIPv4 {
    param (
        [Parameter(Mandatory = $true)]
        [uint64]$Value
    )

    $O1 = [math]::Floor($Value / 16777216)
    $Rest = $Value % 16777216

    $O2 = [math]::Floor($Rest / 65536)
    $Rest = $Rest % 65536

    $O3 = [math]::Floor($Rest / 256)
    $O4 = $Rest % 256

    return "{0}.{1}.{2}.{3}" -f $O1, $O2, $O3, $O4
}

function Test-TcpPort {
    param(
        [Parameter(Mandatory = $true)][string]$ComputerName,
        [Parameter(Mandatory = $true)][int]$Port,
        [int]$TimeoutMilliseconds = 1200
    )

    $Client = New-Object System.Net.Sockets.TcpClient

    try {
        $Async = $Client.BeginConnect($ComputerName, $Port, $null, $null)

        if (-not $Async.AsyncWaitHandle.WaitOne($TimeoutMilliseconds, $false)) {
            return $false
        }

        $Client.EndConnect($Async)
        return $true
    }
    catch {
        return $false
    }
    finally {
        $Client.Close()
    }
}

function Wait-TcpPort {
    param(
        [Parameter(Mandatory = $true)][string]$ComputerName,
        [Parameter(Mandatory = $true)][int]$Port,
        [Parameter(Mandatory = $true)][int]$TimeoutSeconds,
        [string]$Description = "servizio TCP"
    )

    $Deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    while ((Get-Date) -lt $Deadline) {
        if (Test-TcpPort -ComputerName $ComputerName -Port $Port) {
            return $true
        }

        Start-Sleep -Seconds 2
    }

    Write-Warning "$Description non disponibile su $ComputerName`:$Port entro $TimeoutSeconds secondi."
    return $false
}

function Wait-VMState {
    param(
        [Parameter(Mandatory = $true)][string]$VMName,
        [Parameter(Mandatory = $true)][string]$State,
        [Parameter(Mandatory = $true)][int]$TimeoutSeconds
    )

    $Deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    while ((Get-Date) -lt $Deadline) {
        $Current = (Get-VM -Name $VMName -ErrorAction Stop).State.ToString()

        if ($Current -eq $State) {
            return $true
        }

        Start-Sleep -Seconds 2
    }

    return $false
}

function ConvertTo-ShellSingleQuoted {
    param([AllowEmptyString()][string]$Value)

    if ($null -eq $Value) {
        $Value = ""
    }

    # Bash: una singola quote dentro una stringa single-quoted
    # si rappresenta chiudendo la quote, inserendo "'" e riaprendola.
    # Costruiamo la sequenza senza usare escaping C-style, che in
    # PowerShell non e' valido.
    $SingleQuote = [string][char]39
    $DoubleQuote = [string][char]34
    $ShellEscape = $SingleQuote + $DoubleQuote + $SingleQuote + $DoubleQuote + $SingleQuote

    return $SingleQuote + $Value.Replace($SingleQuote, $ShellEscape) + $SingleQuote
}

function Test-NameOrDomain {
    param(
        [Parameter(Mandatory = $true)][string]$Value,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if ($Value.Length -gt 253) {
        throw "$Label troppo lungo: $Value"
    }

    $Parts = $Value.TrimEnd('.').Split('.')

    foreach ($Part in $Parts) {
        if (
            [string]::IsNullOrWhiteSpace($Part) -or
            $Part.Length -gt 63 -or
            $Part -notmatch '^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$'
        ) {
            throw "$Label non valido: $Value"
        }
    }
}

function Show-RollbackHint {
    param([string]$VMName)

    Write-Host
    Write-Host "Rollback manuale, se necessario:" -ForegroundColor Yellow
    Write-Host "  Stop-VM -Name `"$VMName`" -TurnOff"
    Write-Host "  Remove-VM -Name `"$VMName`" -Force"
    Write-Host "  Remove-Item -Recurse -Force `"$VHDDir`""
    Write-Host "  Remove-Item -Recurse -Force `"$VMPath`""
}

# -----------------------------------------------------------------------------
# 0. RACCOLTA PARAMETRI
# -----------------------------------------------------------------------------

if (-not $NonInteractive) {
    Write-Host "=== NEW LAB LINUX VM R2 - PROVISIONING INTERATTIVO ==="
    Write-Host

    $Name = Read-Value -Prompt "Nome nuova VM" -Default $Name
    $IPAddress = Read-Value -Prompt "IPv4 finale" -Default $IPAddress

    $PrefixText = Read-Value -Prompt "Prefisso IPv4" -Default ([string]$Prefix)
    $ParsedPrefix = 0
    if (-not [int]::TryParse($PrefixText, [ref]$ParsedPrefix)) {
        throw "Prefisso IPv4 non valido: $PrefixText"
    }
    $Prefix = $ParsedPrefix

    $Gateway = Read-Value -Prompt "Gateway" -Default $Gateway
    $DNS1 = Read-OptionalValue -Prompt "DNS primario (opzionale)" -Default $DNS1
    $DNS2 = Read-OptionalValue -Prompt "DNS secondario (opzionale)" -Default $DNS2
    $SearchDomain = Read-OptionalValue -Prompt "Search domain (opzionale)" -Default $SearchDomain
    $FinalSwitch = Read-Value -Prompt "Switch Hyper-V finale" -Default $FinalSwitch

    $VlanDefault = ""
    if ($null -ne $VlanId) {
        $VlanDefault = [string]([int]$VlanId)
    }

    $VlanText = Read-Value -Prompt "VLAN ID finale (vuoto = untagged)" -Default $VlanDefault -AllowEmpty

    if ([string]::IsNullOrWhiteSpace($VlanText)) {
        $VlanId = $null
    }
    else {
        $ParsedVlan = 0
        if (-not [int]::TryParse($VlanText, [ref]$ParsedVlan)) {
            throw "VLAN ID non valido: $VlanText"
        }
        $VlanId = $ParsedVlan
    }

    $CPUText = Read-Value -Prompt "CPU" -Default ([string]$ProcessorCount)
    $RAMText = Read-Value -Prompt "RAM startup MB" -Default ([string]$StartupMemoryMB)

    $ParsedCPU = 0
    $ParsedRAM = 0

    if (-not [int]::TryParse($CPUText, [ref]$ParsedCPU)) {
        throw "Numero CPU non valido: $CPUText"
    }

    if (-not [int]::TryParse($RAMText, [ref]$ParsedRAM)) {
        throw "RAM non valida: $RAMText"
    }

    $ProcessorCount = $ParsedCPU
    $StartupMemoryMB = $ParsedRAM
}
else {
    foreach ($Required in @(
        @{ Name = "Name";        Value = $Name },
        @{ Name = "IPAddress";   Value = $IPAddress },
        @{ Name = "Gateway";     Value = $Gateway },
        @{ Name = "FinalSwitch"; Value = $FinalSwitch }
    )) {
        if ([string]::IsNullOrWhiteSpace([string]$Required.Value)) {
            throw "Parametro obbligatorio in modalità -NonInteractive: $($Required.Name)"
        }
    }
}

# Percorsi dipendenti dal nome vengono calcolati solo dopo la raccolta input.
$VMPath = Join-Path $VMRoot $Name
$VHDDir = Join-Path $VHDRoot $Name
$NewVHD = Join-Path $VHDDir "$Name.vhdx"

# -----------------------------------------------------------------------------
# 1. VALIDAZIONE PARAMETRI
# -----------------------------------------------------------------------------

Write-Section "1. VALIDAZIONE PARAMETRI"

if ($Name -notmatch '^[A-Za-z0-9][A-Za-z0-9-]*$') {
    throw "Nome VM/hostname non valido: $Name. Usare solo lettere, numeri e trattino."
}

if ($Name.Length -gt 63) {
    throw "Nome VM/hostname troppo lungo: $Name"
}

if ($Prefix -lt 1 -or $Prefix -gt 30) {
    throw "Prefisso IPv4 non valido: /$Prefix"
}

if ($ProcessorCount -lt 1) {
    throw "ProcessorCount deve essere >= 1."
}

if ($StartupMemoryMB -lt 512) {
    throw "StartupMemoryMB troppo basso: $StartupMemoryMB"
}

if ($MinimumMemoryMB -lt 512 -or $MaximumMemoryMB -lt $StartupMemoryMB) {
    throw "Parametri Dynamic Memory incoerenti."
}

if ($null -ne $VlanId) {
    if (([int]$VlanId) -lt 1 -or ([int]$VlanId) -gt 4094) {
        throw "VLAN ID non valido: $([int]$VlanId). Range ammesso: 1-4094."
    }
}

$IPInt = Convert-IPv4ToInteger $IPAddress
$GWInt = Convert-IPv4ToInteger $Gateway
$ProvisioningInt = Convert-IPv4ToInteger $ProvisioningIP

if (-not [string]::IsNullOrWhiteSpace($DNS1)) {
    [void](Convert-IPv4ToInteger $DNS1)
}

if (-not [string]::IsNullOrWhiteSpace($DNS2)) {
    [void](Convert-IPv4ToInteger $DNS2)
}

if (-not [string]::IsNullOrWhiteSpace($SearchDomain)) {
    Test-NameOrDomain -Value $SearchDomain -Label "Search domain"
}

$HostBits = 32 - $Prefix
$BlockSize = [uint64][math]::Pow(2, $HostBits)
$Network = [uint64]([math]::Floor($IPInt / $BlockSize) * $BlockSize)
$Broadcast = [uint64]($Network + $BlockSize - 1)
$GatewayNetwork = [uint64]([math]::Floor($GWInt / $BlockSize) * $BlockSize)

if ($GatewayNetwork -ne $Network) {
    throw "Il gateway $Gateway non appartiene alla rete $IPAddress/$Prefix."
}

if ($IPInt -eq $Network) {
    throw "L'indirizzo $IPAddress coincide con l'indirizzo di rete."
}

if ($IPInt -eq $Broadcast) {
    throw "L'indirizzo $IPAddress coincide con il broadcast."
}

if ($IPInt -eq $ProvisioningInt) {
    throw "L'IP definitivo non può coincidere con l'IP di provisioning $ProvisioningIP."
}

$NetworkText = Convert-IntegerToIPv4 $Network
$BroadcastText = Convert-IntegerToIPv4 $Broadcast

Write-Host "Rete finale : $NetworkText/$Prefix"
Write-Host "Broadcast   : $BroadcastText"
Write-Host "Validazione parametri: PASS"

# -----------------------------------------------------------------------------
# 2. PREFLIGHT HOST / TOOL
# -----------------------------------------------------------------------------

Write-Section "2. PREFLIGHT HOST E STRUMENTI"

foreach ($Command in @(
    "Get-VM",
    "Get-VHD",
    "New-VM",
    "ssh.exe",
    "ssh-keygen.exe"
)) {
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        throw "Comando richiesto non disponibile: $Command"
    }
}

$ProvisioningSwitchObject = Get-VMSwitch -Name $ProvisioningSwitch -ErrorAction Stop
$FinalSwitchObject = Get-VMSwitch -Name $FinalSwitch -ErrorAction Stop

Write-Host "Provisioning switch : $($ProvisioningSwitchObject.Name)"
Write-Host "Final switch        : $($FinalSwitchObject.Name)"
Write-Host "SSH client          : PASS"
Write-Host "Preflight host      : PASS"

# -----------------------------------------------------------------------------
# 3. PREFLIGHT GOLDEN IMAGE R2
# -----------------------------------------------------------------------------

Write-Section "3. PREFLIGHT GOLDEN IMAGE R2"

$Template = Get-VM -Name $TemplateVM -ErrorAction Stop

if ($Template.State -ne "Off") {
    throw "La golden VM $TemplateVM deve essere spenta."
}

if ($Template.AutomaticStartAction -ne "Nothing") {
    throw "La golden VM deve avere AutomaticStartAction = Nothing."
}

if ($Template.AutomaticCheckpointsEnabled) {
    throw "I checkpoint automatici del template devono essere disabilitati."
}

$TemplateSnapshots = @(Get-VMSnapshot -VMName $TemplateVM -ErrorAction SilentlyContinue)
if ($TemplateSnapshots.Count -ne 0) {
    throw "La golden VM contiene checkpoint."
}

$TemplateNICs = @(Get-VMNetworkAdapter -VMName $TemplateVM)
foreach ($TemplateNIC in $TemplateNICs) {
    if (-not [string]::IsNullOrWhiteSpace($TemplateNIC.SwitchName)) {
        throw "La golden VM deve avere le NIC disconnesse. NIC $($TemplateNIC.Name) -> $($TemplateNIC.SwitchName)"
    }
}

if (-not (Test-Path $TemplateVHD)) {
    throw "Golden VHDX non trovato: $TemplateVHD"
}

$AttachedTemplateDisk = @(Get-VMHardDiskDrive -VMName $TemplateVM)
if ($AttachedTemplateDisk.Count -ne 1) {
    throw "La golden VM deve avere esattamente un VHDX collegato."
}

if ([System.IO.Path]::GetFullPath($AttachedTemplateDisk[0].Path) -ne [System.IO.Path]::GetFullPath($TemplateVHD)) {
    throw "Il VHDX indicato non coincide con il disco collegato alla golden VM."
}

$VHDInfo = Get-VHD -Path $TemplateVHD

if ($VHDInfo.VhdType -eq "Differencing") {
    throw "La golden image non deve essere un disco differenziale."
}

if ($VHDInfo.ParentPath) {
    throw "La golden image possiede un ParentPath."
}

Write-Host "Golden VM           : $TemplateVM"
Write-Host "Golden VHDX         : $TemplateVHD"
Write-Host "Golden image        : PASS"

# -----------------------------------------------------------------------------
# 4. PREFLIGHT DESTINAZIONE / SPAZIO / IP
# -----------------------------------------------------------------------------

Write-Section "4. PREFLIGHT DESTINAZIONE"

if (Get-VM -Name $Name -ErrorAction SilentlyContinue) {
    throw "Esiste già una VM chiamata $Name."
}

if (Test-Path $VMPath) {
    throw "Directory VM già esistente: $VMPath"
}

if (Test-Path $VHDDir) {
    throw "Directory VHD già esistente: $VHDDir"
}

$VHDRootPath = [System.IO.Path]::GetPathRoot($VHDRoot)
$DriveName = $VHDRootPath.Substring(0, 1)
$Drive = Get-PSDrive -Name $DriveName -ErrorAction Stop
$TemplateFile = Get-Item $TemplateVHD
$RequiredFree = [int64]($TemplateFile.Length + 5GB)

Write-Host ("Spazio libero        : {0:N2} GB" -f ($Drive.Free / 1GB))
Write-Host ("Golden VHDX reale   : {0:N2} GB" -f ($TemplateFile.Length / 1GB))
Write-Host "Margine minimo      : 5,00 GB"

if ($Drive.Free -lt $RequiredFree) {
    throw "Spazio insufficiente su $VHDRootPath per copiare la golden e mantenere il margine minimo."
}

$ProvisioningBusy = Test-Connection -ComputerName $ProvisioningIP -Count 1 -Quiet -ErrorAction SilentlyContinue
if ($ProvisioningBusy) {
    throw "L'IP di provisioning $ProvisioningIP risponde già. Potrebbe essere attivo un altro clone non generalizzato."
}

$FinalIPBusy = Test-Connection -ComputerName $IPAddress -Count 1 -Quiet -ErrorAction SilentlyContinue
if ($FinalIPBusy -and -not $Force) {
    throw "L'IP finale $IPAddress risponde già. Usare -Force solo se il controllo è un falso positivo consapevole."
}

Write-Host "$ProvisioningIP libero: PASS"
if ($FinalIPBusy) {
    Write-Warning "$IPAddress risponde, ma -Force consente di proseguire."
}
else {
    Write-Host "$IPAddress non risponde: PASS"
}

# -----------------------------------------------------------------------------
# 5. PIANO E CONFERMA
# -----------------------------------------------------------------------------

Write-Section "5. PIANO DI PROVISIONING"

$VlanTextForPlan = "<untagged>"
if ($null -ne $VlanId) {
    $VlanTextForPlan = [string]([int]$VlanId)
}

Write-Host ("{0,-22} {1}" -f "Nome VM", $Name)
Write-Host ("{0,-22} {1}" -f "Golden", $TemplateVM)
Write-Host ("{0,-22} {1}" -f "Provisioning switch", $ProvisioningSwitch)
Write-Host ("{0,-22} {1}" -f "Provisioning IP", $ProvisioningIP)
Write-Host ("{0,-22} {1}" -f "Switch finale", $FinalSwitch)
Write-Host ("{0,-22} {1}" -f "IPv4 finale", "$IPAddress/$Prefix")
Write-Host ("{0,-22} {1}" -f "Gateway", $Gateway)
Write-Host ("{0,-22} {1}" -f "DNS1", $(if ($DNS1) { $DNS1 } else { "<nessuno>" }))
Write-Host ("{0,-22} {1}" -f "DNS2", $(if ($DNS2) { $DNS2 } else { "<nessuno>" }))
Write-Host ("{0,-22} {1}" -f "Search domain", $(if ($SearchDomain) { $SearchDomain } else { "<nessuno>" }))
Write-Host ("{0,-22} {1}" -f "VLAN", $VlanTextForPlan)
Write-Host ("{0,-22} {1}" -f "CPU", $ProcessorCount)
Write-Host ("{0,-22} {1}" -f "RAM startup", "$StartupMemoryMB MB")

if (-not $NonInteractive -and -not $Force) {
    if (-not (Read-YesNo -Prompt "Procedere con la creazione della VM?" -Default $false)) {
        Write-Host "Operazione annullata."
        exit 0
    }
}

# -----------------------------------------------------------------------------
# 6. COPIA GOLDEN E CREAZIONE VM
# -----------------------------------------------------------------------------

$VMCreated = $false

try {
    Write-Section "6. COPIA GOLDEN VHDX"

    New-Item -ItemType Directory -Path $VHDDir | Out-Null
    Copy-Item -Path $TemplateVHD -Destination $NewVHD
    Write-Host "VHDX creato: $NewVHD"

    Write-Section "7. CREAZIONE VM SU RETE DI PROVISIONING"

    New-VM `
        -Name $Name `
        -Generation 2 `
        -MemoryStartupBytes ($StartupMemoryMB * 1MB) `
        -VHDPath $NewVHD `
        -Path $VMRoot `
        -SwitchName $ProvisioningSwitch |
        Out-Null

    $VMCreated = $true

    Set-VMMemory `
        -VMName $Name `
        -DynamicMemoryEnabled $true `
        -MinimumBytes ($MinimumMemoryMB * 1MB) `
        -StartupBytes ($StartupMemoryMB * 1MB) `
        -MaximumBytes ($MaximumMemoryMB * 1MB) `
        -Buffer 20 `
        -Priority 50

    Set-VMProcessor -VMName $Name -Count $ProcessorCount

    Set-VMFirmware `
        -VMName $Name `
        -EnableSecureBoot On `
        -SecureBootTemplate "MicrosoftUEFICertificateAuthority"

    Set-VM `
        -Name $Name `
        -AutomaticStartAction Nothing `
        -AutomaticCheckpointsEnabled $false `
        -Notes "R2 clone da $TemplateVM; provisioning temporaneo $ProvisioningSwitch/$ProvisioningIP; destinazione $FinalSwitch $IPAddress/$Prefix."

    $NIC = Get-VMNetworkAdapter -VMName $Name
    if (@($NIC).Count -ne 1) {
        throw "La nuova VM deve avere esattamente una NIC."
    }

    $NIC | Rename-VMNetworkAdapter -NewName "LAN"
    $NIC = Get-VMNetworkAdapter -VMName $Name -Name "LAN"
    Set-VMNetworkAdapterVlan -VMNetworkAdapter $NIC -Untagged

    Write-Host "Configurazione VM: PASS"

    Write-Section "8. BOOT DI PROVISIONING E ATTESA SSH"

    Start-VM -Name $Name

    Write-Host "Attendo SSH su $ProvisioningIP`:22 (timeout $SSHWaitSeconds s)..."
    if (-not (Wait-TcpPort -ComputerName $ProvisioningIP -Port 22 -TimeoutSeconds $SSHWaitSeconds -Description "SSH di provisioning")) {
        throw "SSH di provisioning non raggiungibile."
    }

    Write-Host "SSH provisioning: PASS"

    & ssh-keygen.exe -R $ProvisioningIP | Out-Null

    Write-Section "9. GENERALIZZAZIONE GUEST R2"

    $GuestArgs = @(
        $Name,
        "$IPAddress/$Prefix",
        $Gateway,
        $GuestInterface,
        $ProvisioningHost,
        $ProvisioningIP,
        $DNS1,
        $DNS2,
        $SearchDomain,
        "poweroff"
    )

    $QuotedGuestArgs = @()
    foreach ($GuestArg in $GuestArgs) {
        $QuotedGuestArgs += ConvertTo-ShellSingleQuoted ([string]$GuestArg)
    }

    $QuotedGuestScript = ConvertTo-ShellSingleQuoted $GuestGeneralizeScript
    $RemoteCommand = "sudo " + $QuotedGuestScript + " " + ($QuotedGuestArgs -join " ")

    Write-Host "Connessione SSH a $SSHUser@$ProvisioningIP"
    Write-Host "Potrebbero essere richieste la password SSH e la password sudo."
    Write-Host

    & ssh.exe `
        -tt `
        -o "StrictHostKeyChecking=accept-new" `
        "$SSHUser@$ProvisioningIP" `
        $RemoteCommand

    $SSHExit = $LASTEXITCODE
    Write-Host
    Write-Host "ssh exit code: $SSHExit"
    Write-Host "Attendo lo spegnimento guest..."

    if (-not (Wait-VMState -VMName $Name -State "Off" -TimeoutSeconds $PowerOffWaitSeconds)) {
        throw "La VM non si è spenta entro $PowerOffWaitSeconds secondi dopo la generalizzazione."
    }

    Write-Host "Guest generalizzato e VM spenta: PASS"

    Write-Section "10. CAMBIO RETE HYPER-V"

    $NIC = Get-VMNetworkAdapter -VMName $Name -Name "LAN"
    Connect-VMNetworkAdapter -VMNetworkAdapter $NIC -SwitchName $FinalSwitch

    $NIC = Get-VMNetworkAdapter -VMName $Name -Name "LAN"

    if ($null -eq $VlanId) {
        Set-VMNetworkAdapterVlan -VMNetworkAdapter $NIC -Untagged
        Write-Host "VLAN finale: untagged"
    }
    else {
        Set-VMNetworkAdapterVlan -VMNetworkAdapter $NIC -Access -VlanId ([int]$VlanId)
        Write-Host "VLAN finale: Access $([int]$VlanId)"
    }

    Write-Host "Switch finale: $FinalSwitch"
    Write-Host "Cambio rete: PASS"

    Write-Section "11. BOOT FINALE"

    & ssh-keygen.exe -R $IPAddress | Out-Null
    Start-VM -Name $Name

    if (-not $SkipFinalSSHCheck) {
        Write-Host "Attendo SSH finale su $IPAddress`:22 (timeout $FinalSSHWaitSeconds s)..."

        if (Wait-TcpPort -ComputerName $IPAddress -Port 22 -TimeoutSeconds $FinalSSHWaitSeconds -Description "SSH finale") {
            Write-Host "SSH finale: PASS"
        }
        else {
            Write-Warning "SSH finale non raggiungibile. Per reti VLAN/segmentate può essere previsto dalla policy di routing/firewall."
        }
    }
    else {
        Write-Host "Verifica SSH finale: SKIPPED"
    }

    Write-Section "12. REPORT FINALE"

    Get-VM -Name $Name |
        Select-Object `
            Name,
            State,
            Generation,
            ProcessorCount,
            @{N='StartupRAM_MB';E={$_.MemoryStartup / 1MB}},
            AutomaticCheckpointsEnabled |
        Format-Table -AutoSize

    Get-VMNetworkAdapter -VMName $Name |
        Select-Object VMName, Name, SwitchName, MacAddress, Status |
        Format-Table -AutoSize

    Get-VMNetworkAdapterVlan -VMName $Name |
        Format-Table -AutoSize

    Get-VMHardDiskDrive -VMName $Name |
        Select-Object VMName, Path |
        Format-List

    Write-Host
    Write-Host "=== PROVISIONING R2 COMPLETATO ===" -ForegroundColor Green
    Write-Host "VM          : $Name"
    Write-Host "IPv4 atteso : $IPAddress/$Prefix"
    Write-Host "Gateway     : $Gateway"
    Write-Host "Switch      : $FinalSwitch"
    Write-Host "VLAN        : $VlanTextForPlan"
    Write-Host
    Write-Host "Verifica guest consigliata:"
    Write-Host "  ssh $SSHUser@$IPAddress"
    Write-Host "  hostnamectl --static"
    Write-Host "  ip -br -4 addr show $GuestInterface"
    Write-Host "  ip route"
    Write-Host "  resolvectl status $GuestInterface"
}
catch {
    Write-Host
    Write-Host "=== PROVISIONING R2: FAILED ===" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    if ($VMCreated -or (Test-Path $VHDDir)) {
        Show-RollbackHint -VMName $Name
    }

    throw
}