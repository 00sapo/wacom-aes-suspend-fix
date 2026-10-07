#!/bin/bash
set -eu

if [[ $EUID -ne 0 ]]; then
    echo "Run as root: sudo ./install.sh [VID] [PID]" >&2
    exit 1
fi

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
VID="${1:-056a}"
PID="${2:-51dd}"

if [[ ! "$VID" =~ ^[[:xdigit:]]{4}$ || ! "$PID" =~ ^[[:xdigit:]]{4}$ ]]; then
    echo "VID and PID must each be exactly four hexadecimal digits." >&2
    exit 2
fi

VID="${VID,,}"
PID="${PID,,}"

install -m 0755 "$ROOT_DIR/wacom-sleep-fix" /usr/local/sbin/wacom-sleep-fix
install -m 0644 "$ROOT_DIR/wacom-sleep-fix.service" /etc/systemd/system/wacom-sleep-fix.service

cat > /etc/default/wacom-sleep-fix <<EOF_CONFIG
VID=$VID
PID=$PID
EOF_CONFIG

systemctl daemon-reload
systemctl enable wacom-sleep-fix.service

echo "Installed for USB device ${VID}:${PID}."
echo "Test manually before suspending:"
echo "  sudo /usr/local/sbin/wacom-sleep-fix pre"
echo "  sudo /usr/local/sbin/wacom-sleep-fix post"
