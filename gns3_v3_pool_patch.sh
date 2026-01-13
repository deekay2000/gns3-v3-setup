#!/usr/bin/env bash
set -e
echo "Suche nach tasks.py"

TASKS_FILE=$(sudo find / -type f -name tasks.py 2>/dev/null | grep "gns3server/db/tasks.py" | head -n 1)

if [ -z "$TASKS_FILE" ]; then
    echo "tasks.py nicht gefunden. Abbruch."
    exit 1
fi

echo "Pfad gefunden: $TASKS_FILE"

# Backup
BACKUP="${TASKS_FILE}.bak"
if [ ! -f "$BACKUP" ]; then
    echo "Erstelle Backup: $BACKUP"
    cp "$TASKS_FILE" "$BACKUP"
fi

# Prüfen ob schon gepatcht
if grep -q "pool_size=20" "$TASKS_FILE"; then
    echo "Patch ist bereits vorhanden"
    exit 0
fi

echo "Patch wird eingespielt"

python3 <<EOF
from pathlib import Path

path = Path("$TASKS_FILE")
text = path.read_text()

old = """engine = create_async_engine(db_url, connect_args={"check_same_thread": False, "timeout": 20}, future=True)"""

new = """engine = create_async_engine(
        db_url,
        connect_args={
            "check_same_thread": False,
            "timeout": 30
        },
        pool_size=20,
        max_overflow=15,
        pool_timeout=30,
        future=True
    )"""

if old not in text:
    raise SystemExit("Original-Code nicht gefunden – evtl. andere Version?")

path.write_text(text.replace(old, new))
print("Patch angewendet")
EOF
