# Laboratorio – Provisioning automatico di VM Linux da golden image

Materiale operativo associato al laboratorio parallelo del libro **Noi Amministriamo Infrastrutture Linux** (Linuxshell Press).

## Script

- `generalize-lab-clone-r2.sh` — generalizzazione e riconfigurazione del guest Linux derivato dalla golden image.
- `New-LabLinuxVM-R2_2.ps1` — orchestratore PowerShell per Hyper-V, comprensivo dei rami untagged e VLAN.

## Versioni validate

| File | SHA-256 |
|---|---|
| `generalize-lab-clone-r2.sh` | `3a632258e53d134f33808fa20fd968611e0ce4396e6679e024d9909cb739aa05` |
| `New-LabLinuxVM-R2_2.ps1` | `448a870e1aeccbf9c432378feb7355bd7f7a63386ecebb04a5052e75c8144f64` |

Questi file corrispondono alle revisioni effettivamente collaudate nel laboratorio descritto nel libro.

## Licenza

Il codice è distribuito secondo la licenza indicata nel file `LICENSE` alla radice del repository.
