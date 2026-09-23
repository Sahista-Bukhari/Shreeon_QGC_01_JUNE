#!/usr/bin/env bash
# Queues one GCS sequenced still via route-mapping-capture (UDP 14551).
# Prints the planned JPEG path on stdout for QGC SCP (one line, no extra text).
set -euo pipefail

SEQ="${1:?usage: capture.sh <sequence>}"
PORT="${MANUAL_PORT:-14551}"

exec python3 - "$SEQ" "$PORT" <<'PY'
import re
import socket
import sys

seq = int(sys.argv[1])
port = int(sys.argv[2])

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.settimeout(8.0)
try:
    sock.bind(("0.0.0.0", 0))
except OSError:
    pass
payload = f"CAPTURE {seq}".encode()
sock.sendto(payload, ("127.0.0.1", port))
data, _ = sock.recvfrom(4096)
text = data.decode("utf-8", "ignore").strip()

path_match = re.search(r"path=(/\S+)", text)
if path_match:
    print(path_match.group(1))
    sys.exit(0)

if re.match(rf"^QUEUED(\s+seq={seq})?\s*$", text, re.I):
    sys.exit(0)

sys.stderr.write(text + "\n")
sys.exit(1)
PY
