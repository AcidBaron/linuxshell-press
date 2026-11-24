#!/usr/bin/env bash
set -euo pipefail

ZONE=/etc/bind/db.lab.test
BACKUP=/etc/bind/db.lab.test.pre-ch20-nextcloud
sudo cp -a "$ZONE" "$BACKUP"

sudo tee -a "$ZONE" >/dev/null <<'EOF'

; Capitolo 20 - Nextcloud
nextcloud       IN A        10.77.0.50
EOF

sudo python3 - <<'PY2'
from pathlib import Path
import re
from datetime import datetime
path = Path('/etc/bind/db.lab.test')
text = path.read_text()
m = re.search(r'(\d{10})(\s*;\s*Serial\b)', text, re.I)
if not m:
    raise SystemExit('Serial SOA non trovato')
old = m.group(1)
today = datetime.now().strftime('%Y%m%d')
new = str(int(old) + 1) if old.startswith(today) else today + '01'
text = text[:m.start(1)] + new + text[m.end(1):]
path.write_text(text)
print(f'{old} -> {new}')
PY2

sudo named-checkzone lab.test "$ZONE"
sudo rndc reload lab.test
