#!/bin/bash
# Run ON the Raspberry Pi (with sudo): bash install-on-pi.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULTS_DST=/etc/default/shreeon-route-mapping
CONTROL_PORT=14551
WFB_GCS=10.5.0.1
OLD_WFB_SUBNET=10.5.0.0/24

install -m 755 "$SCRIPT_DIR/shreeon_route_mapping.py" /usr/local/libexec/shreeon-route-mapping-capture
install -m 755 "$SCRIPT_DIR/capture.sh" /home/shreeon/capture.sh
install -m 755 "$SCRIPT_DIR/extract_jpeg_thumbnail.py" /home/shreeon/extract_jpeg_thumbnail.py
install -m 644 "$SCRIPT_DIR/route-mapping-capture.service" /etc/systemd/system/route-mapping-capture.service

EXISTING_MANUAL_HOST=""
if [[ -f "$DEFAULTS_DST" ]]; then
  # Preserve the operator-configured bind address across package updates.
  EXISTING_MANUAL_HOST="$(
    # shellcheck disable=SC1090
    . "$DEFAULTS_DST"
    printf '%s' "${MANUAL_HOST:-}"
  )"
fi

install -m 600 "$SCRIPT_DIR/shreeon-route-mapping.default" "$DEFAULTS_DST"
if [[ -n "$EXISTING_MANUAL_HOST" ]]; then
  MANUAL_HOST="$EXISTING_MANUAL_HOST"
else
  MANUAL_HOST="10.5.0.2"
fi
sed -i \
  -e "s|^MANUAL_HOST=.*|MANUAL_HOST=${MANUAL_HOST}|" \
  "$DEFAULTS_DST"
chmod 600 "$DEFAULTS_DST"

# Restrict UDP camera control to the WFB subnet (+ localhost for capture.sh).
if command -v iptables >/dev/null 2>&1; then
  # Rebuild this service's exact rules so upgrades also repair the historical
  # reversed order (DROP was inserted ahead of both ACCEPT rules).
  for rule in \
    "-p udp --dport ${CONTROL_PORT} -s 127.0.0.1 -j ACCEPT" \
    "-p udp --dport ${CONTROL_PORT} -s ${OLD_WFB_SUBNET} -j ACCEPT" \
    "-p udp --dport ${CONTROL_PORT} -s ${WFB_GCS} -j ACCEPT" \
    "-p udp --dport ${CONTROL_PORT} -j DROP"
  do
    # shellcheck disable=SC2086
    while iptables -C INPUT $rule >/dev/null 2>&1; do
      # shellcheck disable=SC2086
      iptables -D INPUT $rule
    done
  done
  iptables -I INPUT 1 -p udp --dport "${CONTROL_PORT}" -j DROP
  iptables -I INPUT 1 -p udp --dport "${CONTROL_PORT}" -s "${WFB_GCS}" -j ACCEPT
  iptables -I INPUT 1 -p udp --dport "${CONTROL_PORT}" -s 127.0.0.1 -j ACCEPT
  echo "Firewall: UDP ${CONTROL_PORT} limited to 127.0.0.1 and WFB GCS ${WFB_GCS}"
else
  echo "WARNING: iptables not found; configure a host firewall for UDP ${CONTROL_PORT}"
fi

systemctl daemon-reload
systemctl restart route-mapping-capture.service
systemctl start wfb-camera.service
sleep 2
journalctl -u route-mapping-capture.service -n 8 --no-pager
echo "Expect: Manual trigger socket: udp://${MANUAL_HOST}:${CONTROL_PORT}"
