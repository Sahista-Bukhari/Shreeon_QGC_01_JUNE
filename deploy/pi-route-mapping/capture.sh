#!/usr/bin/env bash
# Queues one GCS sequenced still via route-mapping-capture (UDP 14551).
# Prints one canonical line for QGC: QUEUED seq=N path=... thumb=...
set -euo pipefail

SEQ="${1:?usage: capture.sh <sequence> [session_token]}"
SESSION_TOKEN="${2:-}"
PORT="${MANUAL_PORT:-14551}"
exec python3 - "$SEQ" "$PORT" "$SESSION_TOKEN" <<'PY'
import re
import socket
import sys

seq = int(sys.argv[1])
port = int(sys.argv[2])
session_token = sys.argv[3].strip()

body = f"CAPTURE {seq}"
if session_token:
    body = f"{body} session={session_token}"
payload = body.encode()

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.settimeout(8.0)
try:
    sock.bind(("127.0.0.1", 0))
except OSError:
    pass
sock.sendto(payload, ("127.0.0.1", port))
data, _ = sock.recvfrom(4096)
text = data.decode("utf-8", "ignore").strip()


def thumb_path_for(sequence: int, full_path: str) -> str:
    from pathlib import Path

    return str(Path(full_path).parent / f"image_{sequence:04d}_thumb.jpg")


def canonicalize_capture_reply(sequence: int, reply: str) -> str | None:
    queued = re.match(
        r"^QUEUED\s+seq=(\d+)\s+path=(/\S+)(?:\s+thumb=(/\S+))?\s*$",
        reply,
        re.I,
    )
    if queued:
        ack_seq = int(queued.group(1))
        full_path = queued.group(2)
        thumb = queued.group(3)
        if ack_seq != sequence:
            return None
        if not thumb:
            thumb = thumb_path_for(sequence, full_path)
        return f"QUEUED seq={sequence} path={full_path} thumb={thumb}"

    bare = re.match(
        rf"^(/[^\s]+/image_{sequence:04d}_gcs_\d{{4}}_[^\s]+\.jpg)\s*$",
        reply,
        re.I,
    )
    if bare:
        full_path = bare.group(1)
        return (
            f"QUEUED seq={sequence} path={full_path} "
            f"thumb={thumb_path_for(sequence, full_path)}"
        )

    path_only = re.search(r"path=(/\S+)", reply)
    if path_only:
        full_path = path_only.group(1)
        return (
            f"QUEUED seq={sequence} path={full_path} "
            f"thumb={thumb_path_for(sequence, full_path)}"
        )

    if re.match(rf"^QUEUED(\s+seq={sequence})?\s*$", reply, re.I):
        return ""
    return None


canonical = canonicalize_capture_reply(seq, text)
if canonical is not None:
    if canonical:
        print(canonical)
    sys.exit(0)

sys.stderr.write(text + "\n")
sys.exit(1)
PY
