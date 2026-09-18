#!/bin/bash
# Run ON the Raspberry Pi (with sudo): bash install-on-pi.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
install -m 755 "$SCRIPT_DIR/shreeon_route_mapping.py" /usr/local/libexec/shreeon-route-mapping-capture
install -m 644 "$SCRIPT_DIR/shreeon-route-mapping.default" /etc/default/shreeon-route-mapping
systemctl daemon-reload
systemctl restart route-mapping-capture.service
sleep 2
journalctl -u route-mapping-capture.service -n 6 --no-pager
echo "Expect: Manual trigger socket: udp://0.0.0.0:14551"
