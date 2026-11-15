Checkpoint-VM -Name "rp01" -SnapshotName "CH11-RP01-PRE-TLS"
Checkpoint-VM -Name "web01" -SnapshotName "CH11-WEB01-PRE-TLS"
Checkpoint-VM -Name "linux-client01" -SnapshotName "CH11-CLIENT-PRE-CA-TRUST"

# Dopo la validazione finale:
Checkpoint-VM -Name "rp01" -SnapshotName "CH11-RP01-TLS-FINAL-VALIDATED"
Checkpoint-VM -Name "web01" -SnapshotName "CH11-WEB01-TLS-FINAL-VALIDATED"
Checkpoint-VM -Name "linux-client01" -SnapshotName "CH11-CLIENT-CA-TRUST-VALIDATED"
