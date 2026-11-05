# Capitolo 3 – Progettare la rete del laboratorio — comandi e configurazioni
> Estratto operativo dal master `Capitolo_03_Progettare_la_rete_e_Appendice_A_Golden_VM.docx`. I blocchi sono riportati nell'ordine del capitolo.

## 3.1 La baseline da preservare

```bash
ip -br -4 addr
ip -4 route
sysctl net.ipv4.ip_forward
sudo nft list ruleset
```

## 3.2 Il client deve usare davvero fw01

```bash
ip -br -4 addr
ip -4 route
ip route get 1.1.1.1
ping -c 3 10.77.0.1
ping -c 3 1.1.1.1
```

## 3.3 Configurazione persistente: Netplan, networkd e resolved

```bash
sudo netplan get
systemctl is-active systemd-networkd
systemctl is-active NetworkManager
systemctl is-active systemd-resolved
resolvectl status
```

## 3.4 La topologia Hyper-V non deve restare implicita

```powershell
Get-VMSwitch |
    Select-Object Name,SwitchType

Get-VMNetworkAdapter `
    -VMName 'fw01','linux-client01' |
    Select-Object VMName,Name,SwitchName,MacAddress

Get-NetIPAddress `
    -InterfaceAlias 'vEthernet (LAB-LAN)' `
    -AddressFamily IPv4

Get-NetRoute `
    -InterfaceAlias 'vEthernet (LAB-LAN)' `
    -AddressFamily IPv4
```

## 3.5 Verificare il livello 2: neighbor table e MAC address

```bash
ping -c 2 10.77.0.101
ping -c 2 10.77.0.254
ip neigh show dev eth1
```

## 3.7 Verificare che le riserve siano realmente libere

```bash
sudo arping -D -q -I eth1 -c 2 -w 2 10.77.0.10
```

## 3.8 Validare la subnet con Python, non soltanto a occhio

```bash
python3 - <<'PY'
from ipaddress import IPv4Network
lab = IPv4Network('10.77.0.0/24')
wan = IPv4Network('172.30.176.0/20')
print(lab.network_address, lab.netmask, lab.broadcast_address)
print('host utilizzabili:', lab.num_addresses - 2)
print('overlap WAN/LAB:', lab.overlaps(wan))
PY
```

## 3.10 Failure test pre-DNS

```bash
getent ahostsv4 fw01.lab.test
echo "exit code: $?"
getent ahostsv4 infra01.lab.test
echo "exit code: $?"
getent ahostsv4 linux-client01.lab.test
echo "exit code: $?"
```

## A.2 La sorgente aveva checkpoint: capire prima la catena AVHDX

```powershell
Get-VMHardDiskDrive -VMName 'linux-client01'
Get-VMSnapshot -VMName 'linux-client01'
Get-VHD -Path <percorso-del-disco-attivo>
```

## A.3 Export e import come copia

```bash
Export-VM -Name 'linux-client01' -Path 'E:\Hyper-V\Exports'

Import-VM `
  -Path '<Virtual Machines>\<id>.vmcx' `
  -Copy `
  -GenerateNewId `
  -VirtualMachinePath 'E:\Hyper-V\VMs\infra01' `
  -VhdDestinationPath 'E:\Hyper-V\VHDX\infra01'
```

## A.4 Consolidare i checkpoint soltanto sulla copia

```powershell
$root = Get-VMSnapshot -VMName 'infra01' |
    Where-Object { -not $_.ParentSnapshotId }

Remove-VMSnapshot `
    -VMSnapshot $root `
    -IncludeAllChildSnapshots `
    -Confirm:$false
```

## A.6 Lo script generalize-lab-clone.sh

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
    cat <<'EOF'
Uso:
  sudo generalize-lab-clone.sh \
      NUOVO_HOSTNAME \
      NUOVO_IP/PREFISSO \
      GATEWAY \
      INTERFACCIA \
      HOSTNAME_ATTESO \
      IP_ATTESO \
      [DNS1] \
      [DNS2]
EOF
}

if [[ $EUID -ne 0 ]]; then
    echo "ERRORE: eseguire lo script con sudo/root."
    exit 1
fi

if (( $# < 6 || $# > 8 )); then
    usage
    exit 2
fi

NEW_HOST="$1"
NEW_CIDR="$2"
GATEWAY="$3"
IFACE="$4"
EXPECTED_HOST="$5"
EXPECTED_IP="$6"
DNS1="${7:-1.1.1.1}"
DNS2="${8:-8.8.8.8}"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="/root/clone-generalize-backup-$STAMP"
NEW_NETPLAN="/etc/netplan/10-lab-static.yaml"

python3 - "$NEW_CIDR" "$GATEWAY" "$DNS1" "$DNS2" <<'PY'
import ipaddress
import sys
cidr, gateway, dns1, dns2 = sys.argv[1:]
iface = ipaddress.ip_interface(cidr)
network = iface.network
gw = ipaddress.ip_address(gateway)
if iface.ip == network.network_address:
    raise SystemExit("ERRORE: IP uguale all'indirizzo di rete")
if iface.ip == network.broadcast_address:
    raise SystemExit("ERRORE: IP uguale al broadcast")
if gw not in network:
    raise SystemExit(f"ERRORE: gateway {gw} fuori da {network}")
ipaddress.ip_address(dns1)
ipaddress.ip_address(dns2)
PY

CURRENT_HOST="$(hostnamectl --static)"
CURRENT_IP="$(ip -4 -o addr show dev "$IFACE" scope global | awk '{print $4}' | cut -d/ -f1 | head -n1)"
[[ "$CURRENT_HOST" == "$EXPECTED_HOST" ]] || exit 10
[[ "$CURRENT_IP" == "$EXPECTED_IP" ]] || exit 11
ip link show "$IFACE" >/dev/null 2>&1 || exit 12

OLD_MACHINE_ID="$(cat /etc/machine-id)"
OLD_SSH_FP="$(ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub | awk '{print $2}')"
install -d -m 700 "$BACKUP_DIR/netplan"
cp -a /etc/hostname "$BACKUP_DIR/"
cp -a /etc/hosts "$BACKUP_DIR/"
for file in /etc/netplan/*.yaml; do
    [[ -e "$file" ]] || continue
    cp -a "$file" "$BACKUP_DIR/netplan/"
done

hostnamectl set-hostname "$NEW_HOST"
TMP_HOSTS="$(mktemp)"
awk -v newhost="$NEW_HOST" '
BEGIN { found = 0 }
$1 == "127.0.1.1" {
    print "127.0.1.1\t" newhost
    found = 1
    next
}
{ print }
END { if (!found) print "127.0.1.1\t" newhost }
' /etc/hosts >"$TMP_HOSTS"
install -o root -g root -m 644 "$TMP_HOSTS" /etc/hosts
rm -f "$TMP_HOSTS"

for file in /etc/netplan/*.yaml; do
    [[ -e "$file" ]] || continue
    mv "$file" "${file}.pre-generalize-$STAMP"
done

cat >"$NEW_NETPLAN" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $IFACE:
      dhcp4: false
      addresses:
        - "$NEW_CIDR"
      nameservers:
        addresses:
          - $DNS1
          - $DNS2
        search: []
      routes:
        - to: default
          via: "$GATEWAY"
EOF
chmod 600 "$NEW_NETPLAN"

if ! netplan generate; then
    rm -f "$NEW_NETPLAN"
    for file in /etc/netplan/*.pre-generalize-"$STAMP"; do
        [[ -e "$file" ]] || continue
        mv "$file" "${file%.pre-generalize-$STAMP}"
    done
    exit 20
fi

truncate -s 0 /etc/machine-id
systemd-machine-id-setup
NEW_MACHINE_ID="$(cat /etc/machine-id)"
[[ -n "$NEW_MACHINE_ID" ]] || exit 30
[[ "$NEW_MACHINE_ID" != "$OLD_MACHINE_ID" ]] || exit 31

rm -f /etc/ssh/ssh_host_*
ssh-keygen -A
sshd -t
NEW_SSH_FP="$(ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub | awk '{print $2}')"
[[ "$NEW_SSH_FP" != "$OLD_SSH_FP" ]] || exit 40

echo "GENERALIZZAZIONE PRE-REBOOT: PASS"
echo "hostname = $NEW_HOST"
echo "IPv4 dopo reboot = $NEW_CIDR"
echo "backup = $BACKUP_DIR"
echo "Eseguire: sudo reboot"
```

## A.9 Proteggere la golden VM

```powershell
Disconnect-VMNetworkAdapter -VMName 'ubuntu2404-base'
Set-VM -Name 'ubuntu2404-base' `
    -AutomaticStartAction Nothing `
    -AutomaticCheckpointsEnabled $false
```

## A.10 Automazione lato Hyper-V: New-LabLinuxVM.ps1

```powershell
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9-]*$')]
    [string]$Name,
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d{1,3}(\.\d{1,3}){3}$')]
    [string]$IPAddress,
    [string]$Gateway = "10.77.0.1",
    [string]$Prefix = "24",
    [string]$SwitchName = "LAB-LAN",
    [string]$TemplateVM = "ubuntu2404-base",
    [string]$TemplateVHD =
        "E:\Hyper-V\VHDX\ubuntu2404-base\ubuntu2404-base.vhdx",
    [string]$VMRoot = "E:\Hyper-V\VMs",
    [string]$VHDRoot = "E:\Hyper-V\VHDX",
    [int]$ProcessorCount = 2,
    [int]$StartupMemoryMB = 2048,
    [int]$MinimumMemoryMB = 1024,
    [int]$MaximumMemoryMB = 4096
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProvisioningIP = "10.77.0.100"
$VMPath = Join-Path $VMRoot $Name
$VHDDir = Join-Path $VHDRoot $Name
$NewVHD = Join-Path $VHDDir "$Name.vhdx"

$Validation = python -c @"
import ipaddress
ip = ipaddress.ip_address("$IPAddress")
gw = ipaddress.ip_address("$Gateway")
network = ipaddress.ip_network("$IPAddress/$Prefix", strict=False)
provisioning = ipaddress.ip_address("$ProvisioningIP")
if gw not in network:
    raise SystemExit("Gateway fuori dalla rete")
if ip in (network.network_address, network.broadcast_address):
    raise SystemExit("Indirizzo host non valido")
if ip == provisioning:
    raise SystemExit("IP definitivo uguale all'IP di provisioning")
print(f"Rete: {network}")
print("Validazione IP: PASS")
"@
if ($LASTEXITCODE -ne 0) { throw "Validazione IP fallita." }
Write-Host $Validation

$Template = Get-VM -Name $TemplateVM -ErrorAction Stop
if ($Template.State -ne "Off") { throw "La golden VM deve essere spenta." }
if ($Template.AutomaticCheckpointsEnabled) { throw "Disabilitare i checkpoint automatici sul template." }
if (@(Get-VMSnapshot -VMName $TemplateVM).Count -ne 0) { throw "La golden VM contiene checkpoint." }
if (-not (Test-Path $TemplateVHD)) { throw "Golden VHDX non trovato." }
$VHDInfo = Get-VHD -Path $TemplateVHD
if ($VHDInfo.VhdType -eq "Differencing" -or $VHDInfo.ParentPath) { throw "La golden image deve essere standalone." }
if (Get-VM -Name $Name -ErrorAction SilentlyContinue) { throw "Esiste già una VM chiamata $Name." }
if (Test-Path $VMPath) { throw "Directory VM già esistente." }
if (Test-Path $VHDDir) { throw "Directory VHD già esistente." }
Get-VMSwitch -Name $SwitchName -ErrorAction Stop | Out-Null
if (Test-Connection -ComputerName $ProvisioningIP -Count 1 -Quiet) { throw "L'IP di provisioning $ProvisioningIP è già in uso." }

New-Item -ItemType Directory -Path $VHDDir | Out-Null
Copy-Item -Path $TemplateVHD -Destination $NewVHD
New-VM -Name $Name -Generation 2 -MemoryStartupBytes ($StartupMemoryMB * 1MB) -VHDPath $NewVHD -Path $VMRoot -SwitchName $SwitchName | Out-Null
Set-VMMemory -VMName $Name -DynamicMemoryEnabled $true -MinimumBytes ($MinimumMemoryMB * 1MB) -StartupBytes ($StartupMemoryMB * 1MB) -MaximumBytes ($MaximumMemoryMB * 1MB) -Buffer 20 -Priority 50
Set-VMProcessor -VMName $Name -Count $ProcessorCount
Set-VMFirmware -VMName $Name -EnableSecureBoot On -SecureBootTemplate "MicrosoftUEFICertificateAuthority"
Set-VM -Name $Name -AutomaticStartAction Nothing -AutomaticCheckpointsEnabled $false -Notes "Clone Linux creato da $TemplateVM; generalizzare prima dell'uso."
Get-VMNetworkAdapter -VMName $Name | Rename-VMNetworkAdapter -NewName "LAN"
Start-VM -Name $Name
Write-Host "VM avviata temporaneamente come ubuntu2404-base/$ProvisioningIP"
Write-Host "Eseguire via SSH generalize-lab-clone.sh con nome e IP definitivi; poi sudo reboot."
```

```powershell
.\New-LabLinuxVM.ps1 `
    -Name 'storage01' `
    -IPAddress '10.77.0.20'
```
