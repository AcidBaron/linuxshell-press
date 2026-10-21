#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
    cat <<'USAGE'
Uso interattivo:
  sudo generalize-lab-clone-r2.sh

Uso parametrico:
  sudo generalize-lab-clone-r2.sh \
      NUOVO_HOSTNAME \
      NUOVO_IP/PREFISSO \
      GATEWAY \
      INTERFACCIA \
      HOSTNAME_ATTESO \
      IP_ATTESO \
      [DNS1] \
      [DNS2] \
      [SEARCH_DOMAIN] \
      [AZIONE_FINALE]

AZIONE_FINALE:
  none       lascia accesa la VM (default parametrico)
  poweroff   spegne la VM dopo le verifiche

Note R2:
  - DNS2 è realmente opzionale.
  - Se DNS1/DNS2 sono omessi, R2 non inserisce resolver pubblici impliciti.
  - SEARCH_DOMAIN è opzionale.
  - "none", "nessuno" o "-" valgono come campo opzionale vuoto.

Esempio:
  sudo generalize-lab-clone-r2.sh \
      pfs-client01 \
      10.88.0.101/24 \
      10.88.0.1 \
      eth0 \
      ubuntu2404-base \
      10.77.0.100 \
      10.88.0.1 \
      "" \
      lab.test \
      poweroff
USAGE
}

die() {
    local code="$1"
    shift
    echo "ERRORE: $*" >&2
    exit "$code"
}

prompt_default() {
    local prompt="$1"
    local default="${2:-}"
    local value=""

    if [[ -n "$default" ]]; then
        read -r -p "$prompt [$default]: " value
        printf '%s' "${value:-$default}"
    else
        read -r -p "$prompt: " value
        printf '%s' "$value"
    fi
}

normalize_optional() {
    local value="${1:-}"
    case "${value,,}" in
        none|nessuno|-)
            printf ''
            ;;
        *)
            printf '%s' "$value"
            ;;
    esac
}

if [[ $EUID -ne 0 ]]; then
    die 1 "eseguire lo script con sudo/root."
fi

MODE="parametric"

if (( $# == 0 )); then
    MODE="interactive"

    [[ -t 0 ]] || die 2 "modalità interattiva richiesta ma stdin non è un terminale."

    echo "=== GENERALIZZAZIONE INTERATTIVA CLONE LINUX R2 ==="
    echo

    DETECTED_IFACE="$(
        ip -4 route show default 2>/dev/null |
        awk 'NR==1 {for (i=1; i<=NF; i++) if ($i=="dev") {print $(i+1); exit}}'
    )"

    if [[ -z "$DETECTED_IFACE" ]]; then
        DETECTED_IFACE="$(
            ip -4 -o addr show scope global |
            awk 'NR==1 {print $2}'
        )"
    fi

    [[ -n "$DETECTED_IFACE" ]] || die 3 "impossibile rilevare l'interfaccia IPv4 di provisioning."

    IFACE="$(prompt_default "Interfaccia di provisioning" "$DETECTED_IFACE")"
    ip link show "$IFACE" >/dev/null 2>&1 || die 12 "interfaccia $IFACE inesistente."

    DETECTED_HOST="$(hostnamectl --static)"
    DETECTED_IP="$(
        ip -4 -o addr show dev "$IFACE" scope global |
        awk '{print $4}' |
        cut -d/ -f1 |
        head -n1
    )"

    [[ -n "$DETECTED_IP" ]] || die 4 "nessun IPv4 globale rilevato su $IFACE."

    echo
    echo "Sorgente rilevata:"
    echo "  hostname : $DETECTED_HOST"
    echo "  IPv4     : $DETECTED_IP"
    echo

    EXPECTED_HOST="$(prompt_default "Hostname sorgente atteso" "$DETECTED_HOST")"
    EXPECTED_IP="$(prompt_default "IPv4 sorgente atteso" "$DETECTED_IP")"

    echo
    NEW_HOST="$(prompt_default "Nuovo hostname")"
    NEW_CIDR="$(prompt_default "Nuovo IPv4/CIDR")"
    GATEWAY="$(prompt_default "Gateway")"
    DNS1="$(prompt_default "DNS primario")"
    DNS2="$(prompt_default "DNS secondario (opzionale)")"
    SEARCH_DOMAIN="$(prompt_default "Search domain (opzionale)" "lab.test")"
    FINAL_ACTION="$(prompt_default "Azione finale: none/poweroff" "poweroff")"

    DNS1="$(normalize_optional "$DNS1")"
    DNS2="$(normalize_optional "$DNS2")"
    SEARCH_DOMAIN="$(normalize_optional "$SEARCH_DOMAIN")"

    echo
    echo "=== RIEPILOGO ==="
    printf '%-22s %s\n' "Sorgente hostname:" "$EXPECTED_HOST"
    printf '%-22s %s\n' "Sorgente IPv4:" "$EXPECTED_IP"
    printf '%-22s %s\n' "Interfaccia:" "$IFACE"
    printf '%-22s %s\n' "Nuovo hostname:" "$NEW_HOST"
    printf '%-22s %s\n' "Nuovo IPv4/CIDR:" "$NEW_CIDR"
    printf '%-22s %s\n' "Gateway:" "$GATEWAY"
    printf '%-22s %s\n' "DNS1:" "${DNS1:-<nessuno>}"
    printf '%-22s %s\n' "DNS2:" "${DNS2:-<nessuno>}"
    printf '%-22s %s\n' "Search domain:" "${SEARCH_DOMAIN:-<nessuno>}"
    printf '%-22s %s\n' "Azione finale:" "$FINAL_ACTION"
    echo

    read -r -p "Procedere? [y/N]: " CONFIRM
    case "${CONFIRM,,}" in
        y|yes|s|si) ;;
        *)
            echo "Operazione annullata."
            exit 0
            ;;
    esac
else
    if (( $# < 6 || $# > 10 )); then
        usage
        exit 2
    fi

    NEW_HOST="$1"
    NEW_CIDR="$2"
    GATEWAY="$3"
    IFACE="$4"
    EXPECTED_HOST="$5"
    EXPECTED_IP="$6"
    DNS1="$(normalize_optional "${7:-}")"
    DNS2="$(normalize_optional "${8:-}")"
    SEARCH_DOMAIN="$(normalize_optional "${9:-}")"
    FINAL_ACTION="${10:-none}"
fi

case "$FINAL_ACTION" in
    none|poweroff) ;;
    *) die 5 "AZIONE_FINALE deve essere 'none' oppure 'poweroff'." ;;
esac

[[ -n "$NEW_HOST" ]] || die 6 "nuovo hostname vuoto."
[[ -n "$NEW_CIDR" ]] || die 7 "nuovo IPv4/CIDR vuoto."
[[ -n "$GATEWAY" ]] || die 8 "gateway vuoto."
[[ -n "$IFACE" ]] || die 9 "interfaccia vuota."
[[ -n "$EXPECTED_HOST" ]] || die 10 "hostname sorgente atteso vuoto."
[[ -n "$EXPECTED_IP" ]] || die 11 "IPv4 sorgente atteso vuoto."

NEW_IP="${NEW_CIDR%/*}"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="/root/clone-generalize-backup-$STAMP"
NEW_NETPLAN="/etc/netplan/10-lab-static.yaml"

echo
echo "=== GENERALIZZAZIONE CLONE LINUX R2 ==="
echo
echo "Modalità       : $MODE"
echo "Nuovo hostname : $NEW_HOST"
echo "Nuovo indirizzo: $NEW_CIDR"
echo "Gateway        : $GATEWAY"
echo "Interfaccia    : $IFACE"
echo "DNS1           : ${DNS1:-<nessuno>}"
echo "DNS2           : ${DNS2:-<nessuno>}"
echo "Search domain  : ${SEARCH_DOMAIN:-<nessuno>}"
echo "Azione finale  : $FINAL_ACTION"
echo

echo "=== 1. VALIDAZIONE PARAMETRI ==="

python3 - "$NEW_HOST" "$NEW_CIDR" "$GATEWAY" "$EXPECTED_IP" "$DNS1" "$DNS2" "$SEARCH_DOMAIN" <<'PY'
import ipaddress
import re
import sys

new_host, cidr, gateway, expected_ip, dns1, dns2, search_domain = sys.argv[1:]

def fail(msg):
    raise SystemExit(f"ERRORE: {msg}")

if len(new_host) > 253:
    fail("hostname troppo lungo")

labels = new_host.rstrip(".").split(".")
if any(
    not label
    or len(label) > 63
    or not re.fullmatch(r"[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?", label)
    for label in labels
):
    fail(f"hostname non valido: {new_host}")

iface = ipaddress.ip_interface(cidr)
network = iface.network
gw = ipaddress.ip_address(gateway)
expected = ipaddress.ip_address(expected_ip)

if iface.version != 4 or gw.version != 4 or expected.version != 4:
    fail("questa revisione del laboratorio accetta solo IPv4")

if iface.ip == network.network_address:
    fail("l'IP coincide con l'indirizzo di rete")
if iface.ip == network.broadcast_address:
    fail("l'IP coincide con il broadcast")
if gw not in network:
    fail(f"gateway {gw} fuori dalla rete {network}")

for label, value in (("DNS1", dns1), ("DNS2", dns2)):
    if value:
        try:
            ipaddress.ip_address(value)
        except ValueError as exc:
            fail(f"{label} non valido: {exc}")

if search_domain:
    domain_labels = search_domain.rstrip(".").split(".")
    if any(
        not label
        or len(label) > 63
        or not re.fullmatch(r"[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?", label)
        for label in domain_labels
    ):
        fail(f"search domain non valido: {search_domain}")

print(f"Rete             : {network}")
print(f"Nuovo IP         : {iface.ip}")
print(f"Gateway          : {gw}")
print(f"IPv4 sorgente    : {expected}")
print(f"DNS1             : {dns1 or '<nessuno>'}")
print(f"DNS2             : {dns2 or '<nessuno>'}")
print(f"Search domain    : {search_domain or '<nessuno>'}")
print("Validazione      : PASS")
PY

echo
echo "=== 2. PREFLIGHT IDENTITA SORGENTE ==="

ip link show "$IFACE" >/dev/null 2>&1 || die 12 "interfaccia $IFACE inesistente."

CURRENT_HOST="$(hostnamectl --static)"
CURRENT_IP="$(
    ip -4 -o addr show dev "$IFACE" scope global |
    awk '{print $4}' |
    cut -d/ -f1 |
    head -n1
)"

if [[ "$CURRENT_HOST" != "$EXPECTED_HOST" ]]; then
    echo "ERRORE: hostname corrente inatteso."
    echo "Atteso : $EXPECTED_HOST"
    echo "Trovato: $CURRENT_HOST"
    exit 10
fi

if [[ "$CURRENT_IP" != "$EXPECTED_IP" ]]; then
    echo "ERRORE: IPv4 corrente inatteso."
    echo "Atteso : $EXPECTED_IP"
    echo "Trovato: $CURRENT_IP"
    exit 11
fi

OLD_MACHINE_ID="$(cat /etc/machine-id)"
OLD_SSH_FP="$(
    ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub |
    awk '{print $2}'
)"

echo "Hostname sorgente : $CURRENT_HOST"
echo "IPv4 sorgente     : $CURRENT_IP"
echo "Machine-ID        : $OLD_MACHINE_ID"
echo "SSH ED25519       : $OLD_SSH_FP"
echo "Preflight         : PASS"

echo
echo "=== 3. BACKUP CONFIGURAZIONE ==="

install -d -m 700 "$BACKUP_DIR"
install -d -m 700 "$BACKUP_DIR/netplan"
cp -a /etc/hostname "$BACKUP_DIR/"
cp -a /etc/hosts "$BACKUP_DIR/"

for file in /etc/netplan/*.yaml; do
    [[ -e "$file" ]] || continue
    cp -a "$file" "$BACKUP_DIR/netplan/"
done

cat >"$BACKUP_DIR/original-identity.txt" <<EOF2
hostname=$CURRENT_HOST
ipv4=$CURRENT_IP
machine_id=$OLD_MACHINE_ID
ssh_ed25519=$OLD_SSH_FP
EOF2

cat >"$BACKUP_DIR/requested-destination.txt" <<EOF2
hostname=$NEW_HOST
ipv4_cidr=$NEW_CIDR
gateway=$GATEWAY
interface=$IFACE
dns1=$DNS1
dns2=$DNS2
search_domain=$SEARCH_DOMAIN
final_action=$FINAL_ACTION
EOF2

echo "Backup: $BACKUP_DIR"

echo
echo "=== 4. HOSTNAME ==="
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
END {
    if (!found)
        print "127.0.1.1\t" newhost
}
' /etc/hosts >"$TMP_HOSTS"
install -o root -g root -m 644 "$TMP_HOSTS" /etc/hosts
rm -f "$TMP_HOSTS"
echo "Hostname impostato: $(hostnamectl --static)"

echo
echo "=== 5. NUOVA CONFIGURAZIONE NETPLAN ==="

for file in /etc/netplan/*.yaml; do
    [[ -e "$file" ]] || continue
    mv "$file" "${file}.pre-generalize-$STAMP"
done

{
    cat <<EOF2
network:
  version: 2
  renderer: networkd
  ethernets:
    $IFACE:
      dhcp4: false
      addresses:
        - "$NEW_CIDR"
EOF2

    if [[ -n "$DNS1" || -n "$DNS2" || -n "$SEARCH_DOMAIN" ]]; then
        echo "      nameservers:"
        if [[ -n "$DNS1" || -n "$DNS2" ]]; then
            echo "        addresses:"
            [[ -n "$DNS1" ]] && echo "          - $DNS1"
            [[ -n "$DNS2" ]] && echo "          - $DNS2"
        fi
        if [[ -n "$SEARCH_DOMAIN" ]]; then
            echo "        search:"
            echo "          - \"$SEARCH_DOMAIN\""
        else
            echo "        search: []"
        fi
    fi

    cat <<EOF2
      routes:
        - to: default
          via: "$GATEWAY"
EOF2
} >"$NEW_NETPLAN"

chmod 600 "$NEW_NETPLAN"

if ! netplan generate; then
    echo "ERRORE: validazione Netplan fallita."
    rm -f "$NEW_NETPLAN"
    for file in /etc/netplan/*.pre-generalize-"$STAMP"; do
        [[ -e "$file" ]] || continue
        mv "$file" "${file%.pre-generalize-$STAMP}"
    done
    echo "Configurazione Netplan originale ripristinata."
    exit 20
fi

echo "Netplan generate: PASS"
cat "$NEW_NETPLAN"

echo
echo "=== 6. RIGENERAZIONE MACHINE-ID ==="
truncate -s 0 /etc/machine-id
systemd-machine-id-setup
NEW_MACHINE_ID="$(cat /etc/machine-id)"
[[ -n "$NEW_MACHINE_ID" ]] || die 30 "nuovo machine-id vuoto."
[[ "$NEW_MACHINE_ID" != "$OLD_MACHINE_ID" ]] || die 31 "machine-id non è cambiato."
echo "Vecchio: $OLD_MACHINE_ID"
echo "Nuovo  : $NEW_MACHINE_ID"
echo "Machine-ID: PASS"

echo
echo "=== 7. RIGENERAZIONE SSH HOST KEYS ==="
rm -f /etc/ssh/ssh_host_*
ssh-keygen -A
sshd -t
NEW_SSH_FP="$(
    ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub |
    awk '{print $2}'
)"
[[ "$NEW_SSH_FP" != "$OLD_SSH_FP" ]] || die 40 "fingerprint SSH non è cambiato."
echo "Vecchia ED25519: $OLD_SSH_FP"
echo "Nuova   ED25519: $NEW_SSH_FP"
echo "sshd -t          : PASS"

echo
echo "=== 8. VERIFICA FINALE PRE-SPEGNIMENTO ==="
echo "Hostname:"
hostnamectl --static
echo
echo "/etc/hosts:"
grep -E '^(127\.0\.0\.1|127\.0\.1\.1)' /etc/hosts
echo
echo "Machine-ID:"
cat /etc/machine-id
echo
echo "SSH ED25519:"
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
echo
echo "Netplan destinazione:"
cat "$NEW_NETPLAN"
echo
echo "IPv4 ANCORA ATTIVO:"
ip -br -4 addr show dev "$IFACE"
echo
echo "=== GENERALIZZAZIONE PRE-BOOT: PASS ==="
echo
echo "IMPORTANTE:"
echo "La rete nuova NON è stata applicata a caldo."
echo "L'host continua temporaneamente a usare $EXPECTED_IP."
echo
echo "Dopo il prossimo boot il sistema dovrà presentarsi come:"
echo "  hostname = $NEW_HOST"
echo "  IPv4     = $NEW_CIDR"
echo
echo "Backup configurazione:"
echo "  $BACKUP_DIR"

if [[ "$FINAL_ACTION" == "poweroff" ]]; then
    echo
    echo "Spegnimento della VM programmato tra 5 secondi..."
    systemd-run --quiet --on-active=5s \
        --unit=clone-generalize-poweroff \
        /usr/bin/systemctl poweroff
    echo "Richiesta di poweroff accodata: PASS"
else
    echo
    echo "Azione finale: none"
    echo "La VM resta accesa sulla rete di provisioning."
    echo "Per il workflow Hyper-V, spegnerla prima di cambiare switch/VLAN."
fi