#!/bin/bash
set -eu

if [[ $EUID -ne 0 ]]; then
    echo "Run as root: sudo ./uninstall.sh" >&2
    exit 1
fi

systemctl disable wacom-sleep-fix.service 2>/dev/null || true
rm -f /etc/systemd/system/wacom-sleep-fix.service
rm -f /etc/default/wacom-sleep-fix
rm -f /usr/local/sbin/wacom-sleep-fix
systemctl daemon-reload

echo "wacom-sleep-fix removed."
